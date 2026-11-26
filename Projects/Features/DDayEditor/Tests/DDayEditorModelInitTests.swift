import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

@MainActor
struct DDayEditorModelInitTests {
  @Test("추가 모드는 빈 제목·오늘 양력·반복 없음·D-day·기본 알림으로 시작하고 저장할 수 없다")
  func addModeStartsEmpty() {
    let model = makeEditor(.add)

    #expect(model.title.isEmpty)
    #expect(model.date == .solar(EditorSample.today))
    #expect(model.calendarKind == .solar)
    #expect(model.repeatRule == RepeatRule.none)
    #expect(model.countingStyle == .dDay)
    #expect(model.reminderIsEnabled)
    #expect(model.enabledReminderDays == [0, 2, 7])
    #expect(model.reminderTime == .defaultReminderTime)
    #expect(model.remindsEveryHundredDays)
    #expect(model.remindsAnniversaries)
    #expect(model.phase == .editing)
    #expect(!model.hasChanges)
    #expect(!model.canSave)
    #expect(model.isTitleEmpty)
    #expect(!model.isEditingExisting)
    #expect(!model.isOriginalMissing)
    #expect(!model.isDateAdjusted)
    #expect(model.alert == nil)

    model.deleteButtonTapped()
    #expect(!model.isDeleteConfirmationPresented)
  }

  @Test(
    "추가 모드의 오늘은 양력 지원 범위로 맞춘다",
    arguments: [
      (EditorSample.day(2051, 1, 1), EditorSample.day(2050, 12, 31)),
      (EditorSample.day(1900, 1, 1), EditorSample.day(1900, 1, 31)),
    ]
  )
  func addModeClampsTodayIntoRange(today: CalendarDay, expected: CalendarDay) {
    let model = makeEditor(.add, today: today)

    #expect(model.date == .solar(expected))
    #expect(!model.hasChanges)
  }

  @Test("수정 모드는 저장된 값으로 시작하고 변경 없음이다 (앞뒤 공백 제목 포함)", arguments: ["엄마 생일", " 생일 "])
  func editModeStartsWithStoredValues(title: String) {
    let dDay = EditorSample.dDay(title: title, reminder: ReminderSettings(
      isEnabled: true,
      enabledDaysBefore: [0, 30],
      time: EditorSample.time(20, 30),
      remindsEveryHundredDays: false,
      remindsAnniversaries: true
    ))
    let (model, _) = makeEditEditor(dDay)

    #expect(model.title == title)
    #expect(model.date == dDay.schedule.date)
    #expect(model.repeatRule == .yearly)
    #expect(model.countingStyle == .dDay)
    #expect(model.reminderIsEnabled)
    #expect(model.enabledReminderDays == [0, 30])
    #expect(model.reminderTime == EditorSample.time(20, 30))
    #expect(!model.remindsEveryHundredDays)
    #expect(model.remindsAnniversaries)
    #expect(model.draft.reminder == dDay.reminder)
    #expect(!model.hasChanges)
    #expect(!model.isDismissDisabled)
    #expect(model.canSave)
    #expect(model.isEditingExisting)
    #expect(!model.isOriginalMissing)
    #expect(!model.isDateAdjusted)
  }

  @Test("알림 날짜 줄은 30일 전 → 7일 전 → 2일 전 → 당일 순서다")
  func reminderDayChoicesInDisplayOrder() {
    #expect(DDayEditorModel.reminderDayChoices == [30, 7, 2, 0])
  }

  @Test("저장 제목에 앞뒤 공백이 있어도 열자마자 변경 없음이고, 그대로 저장하면 정리된 제목이다")
  func editModeUntrimmedStoredTitleHasNoChanges() async {
    let recorder = OutcomeRecorder()
    let (model, fake) = makeEditEditor(EditorSample.dDay(title: "  생일 "), recorder: recorder)

    #expect(!model.hasChanges)
    await model.saveButtonTapped()?.value

    #expect(fake.dDays.map(\.title) == ["생일"])
    #expect(recorder.outcomes.count == 1)
  }

  @Test(
    "고를 수 없는 저장 날짜는 가까운 값으로 맞추고 알린다",
    arguments: [
      (DDayDate.lunar(EditorSample.lunar(2026, 6, 1, leap: true)), DDayDate.lunar(EditorSample.lunar(2026, 6, 1))),
      (.lunar(EditorSample.lunar(2050, 12, 1)), .lunar(EditorSample.lunar(2050, 11, 1))),
      (.lunar(EditorSample.lunar(2051, 1, 1)), .lunar(EditorSample.lunar(2050, 1, 1))),
      (.solar(EditorSample.day(1900, 1, 1)), .solar(EditorSample.day(1900, 1, 31))),
    ]
  )
  func editModeAdjustsUnsupportedDate(stored: DDayDate, expected: DDayDate) {
    let (model, _) = makeEditEditor(EditorSample.dDay(date: stored))

    #expect(model.date == expected)
    #expect(model.isDateAdjusted)
    #expect(model.hasChanges)
    #expect(model.isDismissDisabled)
  }

  enum DateEvent: CaseIterable {
    case kind, solarDay, lunarYear, lunarMonth, lunarLeap, lunarDay
  }

  @Test("받아들인 날짜 이벤트는 맞춤 안내를 끄지만 변경 있음은 남는다", arguments: DateEvent.allCases)
  func dateEventClearsAdjustedNotice(event: DateEvent) {
    // 양력 이벤트는 양력 저장값(범위 밖), 나머지는 음력 저장값(없는 윤달)으로 연다.
    let stored: DDayDate = event == .solarDay
      ? .solar(EditorSample.day(1900, 1, 1))
      : .lunar(EditorSample.lunar(2026, 6, 1, leap: true))
    let (model, _) = makeEditEditor(EditorSample.dDay(date: stored))
    #expect(model.isDateAdjusted)

    switch event {
    case .kind: model.calendarKindChanged(.solar)
    case .solarDay: model.solarDayChanged(EditorSample.day(1900, 1, 31))
    case .lunarYear: model.lunarYearChanged(2026)
    case .lunarMonth: model.lunarMonthChanged(6)
    case .lunarLeap: model.lunarLeapMonthChanged(false)
    case .lunarDay: model.lunarDayChanged(1)
    }

    #expect(!model.isDateAdjusted)
    #expect(model.hasChanges)
  }

  @Test("종류가 맞지 않아 무시된 날짜 이벤트는 안내를 끄지 않는다")
  func ignoredDateEventKeepsAdjustedNotice() {
    let (model, _) = makeEditEditor(EditorSample.dDay(date: .solar(EditorSample.day(1900, 1, 1))))

    model.lunarYearChanged(2000)
    model.lunarMonthChanged(3)
    model.lunarLeapMonthChanged(true)
    model.lunarDayChanged(3)
    model.calendarKindChanged(.solar)

    #expect(model.isDateAdjusted)
    #expect(model.date == .solar(EditorSample.day(1900, 1, 31)))
  }
}
