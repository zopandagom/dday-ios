import Core
import DDayStoreInterface
import Foundation

public extension DDayEditorModel {
  // MARK: - 파생 값

  var calendarKind: CalendarKind {
    switch self.date {
    case .solar: .solar
    case .lunar: .lunar
    }
  }

  /// 앞뒤 공백을 정리하면 빈 제목.
  var isTitleEmpty: Bool { Self.trimmed(self.title).isEmpty }
  var canSave: Bool { !self.isTitleEmpty && self.phase == .editing }
  var isBusy: Bool { self.phase == .saving || self.phase == .deleting }
  /// 기념일 알림 토글은 D+·1일째 방식일 때만 보인다 (값은 늘 저장).
  var showsMilestoneReminders: Bool { self.countingStyle != .dDay }
  /// 알림 날짜 줄의 표시 순서: 30일 전 → 7일 전 → 2일 전 → 당일.
  static let reminderDayChoices: [Int] = ReminderSettings.daysBeforeChoices.reversed()

  /// 저장할 값: 제목 정리, 알림은 `ReminderSettings` 가 정규화.
  internal var draft: DDayDraft {
    DDayDraft(
      title: Self.trimmed(self.title),
      schedule: DDaySchedule(date: self.date, repeatRule: self.repeatRule, countingStyle: self.countingStyle),
      reminder: ReminderSettings(
        isEnabled: self.reminderIsEnabled,
        enabledDaysBefore: self.enabledReminderDays,
        time: self.reminderTime,
        remindsEveryHundredDays: self.remindsEveryHundredDays,
        remindsAnniversaries: self.remindsAnniversaries
      )
    )
  }

  /// 음력 선택기의 선택지. 양력이면 같은 날의 음력 기준.
  internal var lunarChoices: LunarPickerOptions.Choices {
    switch self.date {
    case let .lunar(lunar):
      return LunarPickerOptions.choices(for: lunar)
    case let .solar(day):
      let lunar = KoreanLunarCalendar.lunarDate(from: day)
        ?? LunarPickerOptions.normalized(year: day.year, month: 1, isLeapMonth: false, day: 1)
      return LunarPickerOptions.choices(for: lunar)
    }
  }

  // MARK: - 날짜·제목 정리

  internal static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal static func clampedSolar(_ day: CalendarDay) -> CalendarDay {
    let range = KoreanLunarCalendar.supportedSolarRange
    return min(max(day, range.lowerBound), range.upperBound)
  }

  /// 고를 수 있는 날짜로 맞춘 값과 맞췄는지.
  internal static func selectable(_ date: DDayDate) -> (DDayDate, Bool) {
    switch date {
    case let .solar(day):
      let clamped = self.clampedSolar(day)
      return (.solar(clamped), clamped != day)
    case let .lunar(lunar):
      guard KoreanLunarCalendar.solarDay(from: lunar) == nil else { return (date, false) }
      let normalized = LunarPickerOptions.normalized(
        year: lunar.year,
        month: lunar.month,
        isLeapMonth: lunar.isLeapMonth,
        day: lunar.day
      )
      return (.lunar(normalized), true)
    }
  }
}
