import Core
import Foundation

/// 날짜 선택기의 `Date` 와 시각 없는 값(`CalendarDay`·`TimeOfDay`) 사이 변환 (순수).
/// View 가 환경 시간대를 넘기고, 같은 시간대로 왕복하므로 날짜가 하루 밀리지 않는다.
enum EditorDateConversion {
  /// 그 날 12:00 (그레고리력, `timeZone`). 자정이 없는 서머타임 전환일에도 그 날의 순간이 있도록 정오를 쓴다.
  static func date(from day: CalendarDay, in timeZone: TimeZone) -> Date {
    let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
    return self.calendar(timeZone).date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
  }

  static func calendarDay(from date: Date, in timeZone: TimeZone) -> CalendarDay {
    CalendarDay(date, in: timeZone)
  }

  /// 2001-01-01 hh:mm (그레고리력, `timeZone`).
  static func date(from time: TimeOfDay, in timeZone: TimeZone) -> Date {
    let components = DateComponents(year: 2001, month: 1, day: 1, hour: time.hour, minute: time.minute)
    return self.calendar(timeZone).date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
  }

  /// 그 시간대의 시·분.
  static func timeOfDay(from date: Date, in timeZone: TimeZone) -> TimeOfDay {
    let components = self.calendar(timeZone).dateComponents([.hour, .minute], from: date)
    return TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0) ?? .defaultReminderTime
  }

  private static func calendar(_ timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }
}
