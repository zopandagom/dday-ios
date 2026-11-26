import Foundation

/// 하루 안의 시각(시·분). 시간대는 알림을 예약하는 쪽이 기기 시간대로 해석한다.
public struct TimeOfDay: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let hour: Int
  public let minute: Int

  /// 0~23시, 0~59분만 만든다.
  public init?(hour: Int, minute: Int) {
    guard (0 ... 23).contains(hour), (0 ... 59).contains(minute) else { return nil }
    self.hour = hour
    self.minute = minute
  }

  /// 기본 알림 시각, 오전 9시.
  public static let defaultReminderTime = TimeOfDay(uncheckedHour: 9, minute: 0)

  private init(uncheckedHour hour: Int, minute: Int) {
    self.hour = hour
    self.minute = minute
  }

  public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
    (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
  }

  public var description: String {
    "\(self.hour):\(self.minute < 10 ? "0" : "")\(self.minute)"
  }
}

/// 알림을 계획할 디데이 하나.
public struct ReminderSource: Hashable, Sendable {
  public let dDayID: UUID
  public let schedule: DDaySchedule
  /// 며칠 전에 알릴지 (0 = 당일). 음수는 무시하고 중복은 하나로 친다. 비어 있으면 알림 없음.
  public let daysBefore: [Int]
  public let time: TimeOfDay

  public init(dDayID: UUID, schedule: DDaySchedule, daysBefore: [Int], time: TimeOfDay) {
    self.dDayID = dDayID
    self.schedule = schedule
    self.daysBefore = daysBefore
    self.time = time
  }
}

/// 예약할 알림 하나.
public struct PlannedReminder: Hashable, Sendable {
  public let dDayID: UUID
  public let daysBefore: Int
  /// 알림이 가리키는 디데이 날짜 (알림 문구용)
  public let eventDay: CalendarDay
  /// 알림을 울릴 날짜
  public let day: CalendarDay
  public let time: TimeOfDay

  public init(dDayID: UUID, daysBefore: Int, eventDay: CalendarDay, day: CalendarDay, time: TimeOfDay) {
    self.dDayID = dDayID
    self.daysBefore = daysBefore
    self.eventDay = eventDay
    self.day = day
    self.time = time
  }
}

/// 디데이 목록에서 예약할 로컬 알림을 고른다 (순수 로직). iOS 예약 한도 64개라 가까운 순 최대 60개만 고르고,
/// 앱 실행·복귀·디데이 변경 때 다시 계산한다 (PRODUCT §2).
public enum NotificationPlanner {
  public static let maximumCount = 60
  /// 매년 반복하는 디데이는 다음 날짜 이만큼까지 알림을 만든다.
  public static let yearlyOccurrenceCount = 2

  /// - 지난 알림과 오늘이면서 시각이 `now` 이하인 알림은 뺀다.
  /// - 세는 방식이 D+(`.dPlus`) 인 디데이는 뺀다.
  /// - 날짜 → 시각 → 디데이 id → 며칠 전 순으로 정렬해 `limit` 개로 자른다.
  public static func plan(
    _ sources: [ReminderSource],
    today: CalendarDay,
    now: TimeOfDay,
    limit: Int = maximumCount
  ) -> [PlannedReminder] {
    var reminders: [PlannedReminder] = []
    for source in sources where source.schedule.countingStyle != .dPlus {
      let offsets = Set(source.daysBefore.filter { $0 >= 0 })
      let events = DDayCalculator.occurrences(
        of: source.schedule,
        onOrAfter: today,
        limit: source.schedule.repeatRule == .yearly ? self.yearlyOccurrenceCount : 1
      )
      for eventDay in events {
        for offset in offsets {
          guard let day = eventDay.adding(days: -offset),
                day > today || (day == today && source.time > now)
          else {
            continue
          }
          reminders.append(
            PlannedReminder(
              dDayID: source.dDayID, daysBefore: offset, eventDay: eventDay, day: day, time: source.time
            )
          )
        }
      }
    }
    reminders.sort { lhs, rhs in
      if lhs.day != rhs.day {
        return lhs.day < rhs.day
      }
      if lhs.time != rhs.time {
        return lhs.time < rhs.time
      }
      if lhs.dDayID != rhs.dDayID {
        return lhs.dDayID.uuidString < rhs.dDayID.uuidString
      }
      return lhs.daysBefore < rhs.daysBefore
    }
    return Array(reminders.prefix(max(limit, 0)))
  }
}
