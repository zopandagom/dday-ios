import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

@MainActor
struct DDayEditorModelInputTests {
  /// 음력 날짜로 연 수정 모델.
  func lunarEditor(_ lunar: LunarDate) -> DDayEditorModel {
    makeEditEditor(EditorSample.dDay(date: .lunar(lunar))).0
  }

  // MARK: 제목

  @Test("제목은 입력 그대로 두고 저장값은 앞뒤 공백을 정리한다")
  func titleChangedTrimsForSaving() {
    let model = makeEditor(.add)

    model.titleChanged("  생일 \n")

    #expect(model.title == "  생일 \n")
    #expect(model.draft.title == "생일")
    #expect(!model.isTitleEmpty)
    #expect(model.canSave)
  }

  @Test("공백만 있는 제목은 저장할 수 없다")
  func whitespaceTitleCannotSave() {
    let model = makeEditor(.add)

    model.titleChanged("   \n")

    #expect(model.isTitleEmpty)
    #expect(!model.canSave)
  }

  @Test("값을 바꿨다 되돌리면 변경 없음이다 (제목 앞뒤 공백만 바꾼 것 포함)")
  func revertingValuesHasNoChanges() {
    let (model, _) = makeEditEditor()

    model.titleChanged("다른 제목")
    model.repeatRuleChanged(.none)
    model.reminderEnabledChanged(false)
    #expect(model.hasChanges)
    #expect(model.isDismissDisabled)

    model.titleChanged("  엄마 생일 ")
    model.repeatRuleChanged(.yearly)
    model.reminderEnabledChanged(true)

    #expect(!model.hasChanges)
    #expect(!model.isDismissDisabled)
  }

  // MARK: 날짜

  @Test("양력↔음력 전환은 같은 날을 유지한다")
  func switchSolarToLunarKeepsSameDay() {
    let model = makeEditor(.add, today: EditorSample.day(2025, 8, 22))

    model.calendarKindChanged(.lunar)
    #expect(model.date == .lunar(EditorSample.lunar(2025, 6, 29, leap: true)))
    #expect(model.calendarKind == .lunar)

    model.calendarKindChanged(.solar)
    #expect(model.date == .solar(EditorSample.day(2025, 8, 22)))
  }

  @Test("같은 종류로 전환은 무시한다")
  func switchToSameKindIgnored() {
    let model = makeEditor(.add)

    model.calendarKindChanged(.solar)

    #expect(model.date == .solar(EditorSample.today))
  }

  @Test(
    "양력 날짜는 지원 범위로 맞춘다",
    arguments: [
      (EditorSample.day(1900, 1, 30), EditorSample.day(1900, 1, 31)),
      (EditorSample.day(2051, 1, 1), EditorSample.day(2050, 12, 31)),
      (EditorSample.day(2030, 5, 5), EditorSample.day(2030, 5, 5)),
    ]
  )
  func solarDayChangedClampsToRange(input: CalendarDay, expected: CalendarDay) {
    let model = makeEditor(.add)

    model.solarDayChanged(input)

    #expect(model.date == .solar(expected))
  }

  @Test(
    "음력 연 변경은 고를 수 있는 값으로 맞춘다",
    arguments: [
      (EditorSample.lunar(2025, 6, 15, leap: true), 2026, EditorSample.lunar(2026, 6, 15)),
      (EditorSample.lunar(2049, 12, 29), 2050, EditorSample.lunar(2050, 11, 18)),
      (EditorSample.lunar(2026, 1, 30), 2027, EditorSample.lunar(2027, 1, 29)),
    ]
  )
  func lunarYearChangedNormalizes(start: LunarDate, year: Int, expected: LunarDate) {
    let model = self.lunarEditor(start)

    model.lunarYearChanged(year)

    #expect(model.date == .lunar(expected))
  }

  @Test(
    "음력 월 변경은 고를 수 있는 값으로 맞춘다",
    arguments: [
      (EditorSample.lunar(2025, 6, 29, leap: true), 7, EditorSample.lunar(2025, 7, 29)),
      (EditorSample.lunar(2050, 10, 30), 11, EditorSample.lunar(2050, 11, 18)),
      (EditorSample.lunar(2050, 10, 1), 12, EditorSample.lunar(2050, 11, 1)),
    ]
  )
  func lunarMonthChangedNormalizes(start: LunarDate, month: Int, expected: LunarDate) {
    let model = self.lunarEditor(start)

    model.lunarMonthChanged(month)

    #expect(model.date == .lunar(expected))
  }

  @Test(
    "윤달 변경은 그해 그 달에 윤달이 있을 때만 바뀐다",
    arguments: [
      (EditorSample.lunar(2025, 6, 30), true, EditorSample.lunar(2025, 6, 29, leap: true)),
      (EditorSample.lunar(2026, 6, 1), true, EditorSample.lunar(2026, 6, 1)),
      (EditorSample.lunar(2025, 6, 29, leap: true), false, EditorSample.lunar(2025, 6, 29)),
    ]
  )
  func lunarLeapMonthChangedNormalizes(start: LunarDate, isLeap: Bool, expected: LunarDate) {
    let model = self.lunarEditor(start)

    model.lunarLeapMonthChanged(isLeap)

    #expect(model.date == .lunar(expected))
  }

  @Test("음력 일 변경은 고를 수 있는 마지막 날까지로 맞춘다")
  func lunarDayChangedNormalizes() {
    let model = self.lunarEditor(EditorSample.lunar(2050, 11, 10))

    model.lunarDayChanged(19)
    #expect(model.date == .lunar(EditorSample.lunar(2050, 11, 18)))

    model.lunarDayChanged(5)
    #expect(model.date == .lunar(EditorSample.lunar(2050, 11, 5)))
  }

  @Test("양력일 때 음력 이벤트는 무시한다")
  func lunarEventsIgnoredInSolarMode() {
    let model = makeEditor(.add)

    model.lunarYearChanged(2000)
    model.lunarMonthChanged(3)
    model.lunarLeapMonthChanged(true)
    model.lunarDayChanged(3)

    #expect(model.date == .solar(EditorSample.today))
  }

  @Test("음력일 때 양력 이벤트는 무시한다")
  func solarEventIgnoredInLunarMode() {
    let model = self.lunarEditor(EditorSample.lunar(2026, 10, 18))

    model.solarDayChanged(EditorSample.day(2030, 1, 1))

    #expect(model.date == .lunar(EditorSample.lunar(2026, 10, 18)))
  }

  // MARK: 반복·세는 방식

  @Test("반복 규칙 변경")
  func repeatRuleChanged() {
    let model = makeEditor(.add)

    model.repeatRuleChanged(.yearly)

    #expect(model.repeatRule == .yearly)
    #expect(model.draft.schedule.repeatRule == .yearly)
  }

  @Test("세는 방식 변경은 알림 값을 건드리지 않는다", arguments: CountingStyle.allCases)
  func countingStyleChanged(style: CountingStyle) {
    let (model, _) = makeEditEditor()
    let reminder = model.draft.reminder

    model.countingStyleChanged(style)

    #expect(model.countingStyle == style)
    #expect(model.draft.schedule.countingStyle == style)
    #expect(model.draft.reminder == reminder)
  }

  // MARK: 알림

  @Test("알림 이벤트는 모든 세는 방식에서 반영된다", arguments: CountingStyle.allCases)
  func reminderEventsWorkInEveryCountingStyle(style: CountingStyle) {
    let (model, _) = makeEditEditor(EditorSample.dDay(countingStyle: style))

    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: false)
    model.reminderDayEnabledChanged(daysBefore: 7, isEnabled: true)
    model.reminderTimeChanged(EditorSample.time(7, 0))
    model.reminderEnabledChanged(false)

    #expect(!model.reminderIsEnabled)
    #expect(model.enabledReminderDays == [0, 7])
    #expect(model.reminderTime == EditorSample.time(7, 0))
    #expect(model.draft.reminder.enabledDaysBefore == [0, 7])
    #expect(model.draft.reminder.time == EditorSample.time(7, 0))
    #expect(!model.draft.reminder.isEnabled)
    #expect(model.hasChanges)
  }

  @Test("알림 전체를 꺼도 켜진 날짜는 남는다")
  func reminderEnabledChangedKeepsDays() {
    let model = makeEditor(.add)

    model.reminderEnabledChanged(false)

    #expect(!model.reminderIsEnabled)
    #expect(model.enabledReminderDays == [0, 2, 7])
    #expect(model.draft.reminder.enabledDaysBefore == [0, 2, 7])
    #expect(model.draft.reminder.scheduledDaysBefore.isEmpty)
  }

  @Test("알림 전체가 꺼져 있어도 날짜 켜기·끄기는 반영된다")
  func reminderDayEnabledChangedWhileReminderDisabled() {
    let model = makeEditor(.add)
    model.reminderEnabledChanged(false)

    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: true)
    model.reminderDayEnabledChanged(daysBefore: 2, isEnabled: false)

    #expect(model.enabledReminderDays == [0, 7, 30])
    #expect(model.draft.reminder.enabledDaysBefore == [0, 7, 30])
    #expect(model.draft.reminder.scheduledDaysBefore.isEmpty)

    model.reminderEnabledChanged(true)
    #expect(model.draft.reminder.scheduledDaysBefore == [0, 7, 30])
  }

  @Test("날짜를 끄면 계획기 입력에서 빠지고, 30일 전을 켜면 들어간다")
  func reminderDayEnabledChanged() {
    let model = makeEditor(.add)

    model.reminderDayEnabledChanged(daysBefore: 2, isEnabled: false)
    #expect(model.enabledReminderDays == [0, 7])
    #expect(model.draft.reminder.scheduledDaysBefore == [0, 7])

    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: true)
    #expect(model.draft.reminder.scheduledDaysBefore == [0, 7, 30])
    #expect(model.hasChanges)

    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: false)
    model.reminderDayEnabledChanged(daysBefore: 2, isEnabled: true)
    #expect(model.draft.reminder.scheduledDaysBefore == [0, 2, 7])
    #expect(!model.hasChanges)
  }

  @Test("날짜 하나를 뒤집으면 변경 있음, 다시 뒤집으면 변경 없음", arguments: [30, 7, 2, 0])
  func reminderDayToggleRoundTrip(daysBefore: Int) {
    let model = makeEditor(.add)
    let wasEnabled = model.enabledReminderDays.contains(daysBefore)

    model.reminderDayEnabledChanged(daysBefore: daysBefore, isEnabled: !wasEnabled)
    #expect(model.enabledReminderDays.contains(daysBefore) == !wasEnabled)
    #expect(model.hasChanges)

    model.reminderDayEnabledChanged(daysBefore: daysBefore, isEnabled: wasEnabled)
    #expect(model.enabledReminderDays.contains(daysBefore) == wasEnabled)
    #expect(!model.hasChanges)
  }

  @Test("고정 선택지 밖의 날짜는 무시한다", arguments: [-1, 1, 3, 14, 365])
  func reminderDayOutsideChoicesIgnored(daysBefore: Int) {
    let model = makeEditor(.add)

    model.reminderDayEnabledChanged(daysBefore: daysBefore, isEnabled: true)

    #expect(model.enabledReminderDays == [0, 2, 7])
    #expect(!model.hasChanges)
  }

  @Test("알림 시간 변경")
  func reminderTimeChanged() {
    let model = makeEditor(.add)

    model.reminderTimeChanged(EditorSample.time(21, 15))

    #expect(model.reminderTime == EditorSample.time(21, 15))
    #expect(model.draft.reminder.time == EditorSample.time(21, 15))
  }
}
