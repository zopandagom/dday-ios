import Core
import DDayStoreInterface
import Testing

struct ReminderSettingsTests {
  @Test("고를 수 있는 알림 날짜는 당일·2일 전·7일 전·30일 전 오름차순이다")
  func choicesAreFixed() {
    #expect(ReminderSettings.daysBeforeChoices == [0, 2, 7, 30])
  }

  @Test("선택지 밖 값(-1, 1, 14, 365)은 버린다")
  func dropsValuesOutsideChoices() {
    let settings = ReminderSettings(enabledDaysBefore: [-1, 0, 1, 14, 30, 365], time: Sample.time(9, 0))
    #expect(settings.enabledDaysBefore == [0, 30])
  }

  @Test("계획기에 넘길 날짜는 켜진 날짜 오름차순이다")
  func scheduledDaysBeforeAscending() {
    let settings = ReminderSettings(enabledDaysBefore: [30, 0, 7], time: Sample.time(9, 0))
    #expect(settings.scheduledDaysBefore == [0, 7, 30])
  }

  @Test("빈 집합은 빈 집합 그대로 둔다")
  func keepsEmptyDays() {
    let settings = ReminderSettings(enabledDaysBefore: [], time: Sample.time(9, 0))
    #expect(settings.enabledDaysBefore.isEmpty)
    #expect(settings.isEnabled)
    #expect(settings.scheduledDaysBefore.isEmpty)
  }

  @Test("기본값은 켜짐, 당일·2일 전·7일 전 켜짐(30일 전 꺼짐), 오전 9시, 기념일 토글 둘 다 켜짐이다")
  func defaultSettings() {
    let settings = ReminderSettings.default
    #expect(settings.isEnabled)
    #expect(settings.enabledDaysBefore == [0, 2, 7])
    #expect(!settings.enabledDaysBefore.contains(30))
    #expect(settings.time == Sample.time(9, 0))
    #expect(settings.remindsEveryHundredDays)
    #expect(settings.remindsAnniversaries)
  }

  @Test("기념일 토글은 기본 켜짐이고 끈 값도 그대로 받는다")
  func milestoneTogglesDefaultOn() {
    let byDefault = ReminderSettings(enabledDaysBefore: [0], time: Sample.time(9, 0))
    #expect(byDefault.remindsEveryHundredDays && byDefault.remindsAnniversaries)
    let off = ReminderSettings(
      enabledDaysBefore: [0],
      time: Sample.time(9, 0),
      remindsEveryHundredDays: false,
      remindsAnniversaries: false
    )
    #expect(!off.remindsEveryHundredDays && !off.remindsAnniversaries)
  }

  @Test("전체 알림을 꺼도 기념일 토글 값은 남는다")
  func milestoneTogglesKeptWhenDisabled() {
    let settings = ReminderSettings(
      isEnabled: false,
      enabledDaysBefore: [0],
      time: Sample.time(9, 0),
      remindsEveryHundredDays: false,
      remindsAnniversaries: true
    )
    #expect(!settings.remindsEveryHundredDays)
    #expect(settings.remindsAnniversaries)
    #expect(settings.scheduledDaysBefore.isEmpty)
  }

  @Test("기념일 토글이 다르면 다른 설정이다", arguments: [(false, true), (true, false), (false, false)])
  func milestoneTogglesAffectEquality(hundred: Bool, years: Bool) {
    let changed = ReminderSettings(
      enabledDaysBefore: [0, 2, 7],
      time: .defaultReminderTime,
      remindsEveryHundredDays: hundred,
      remindsAnniversaries: years
    )
    #expect(changed != .default)
    #expect(changed.enabledDaysBefore == ReminderSettings.default.enabledDaysBefore)
  }

  @Test("전체 알림이 꺼져 있으면 계획기에 넘길 날짜가 없고 켜진 날짜는 남는다")
  func scheduledDaysBeforeEmptyWhenDisabled() {
    let settings = ReminderSettings(isEnabled: false, enabledDaysBefore: [0, 2], time: Sample.time(9, 0))
    #expect(settings.scheduledDaysBefore.isEmpty)
    #expect(settings.enabledDaysBefore == [0, 2])
  }
}
