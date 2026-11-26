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
  /// 며칠 전에 알릴지 (0 = 당일). 음수는 무시하고 중복은 하나로 친다. 비어 있으면 알림 없음 (기념일 알림 포함).
  public let daysBefore: [Int]
  public let time: TimeOfDay
  /// D+·1일째 방식에서 100일 단위 기념일에도 알릴지. dDay 방식은 보지 않는다.
  public let remindsEveryHundredDays: Bool
  /// D+·1일째 방식에서 N주년에도 알릴지. dDay 방식은 보지 않는다.
  public let remindsAnniversaries: Bool

  /// 기념일 토글은 기본값이 없다: 호출부가 저장된 설정을 빠뜨리지 않게 한다.
  public init(
    dDayID: UUID,
    schedule: DDaySchedule,
    daysBefore: [Int],
    time: TimeOfDay,
    remindsEveryHundredDays: Bool,
    remindsAnniversaries: Bool
  ) {
    self.dDayID = dDayID
    self.schedule = schedule
    self.daysBefore = daysBefore
    self.time = time
    self.remindsEveryHundredDays = remindsEveryHundredDays
    self.remindsAnniversaries = remindsAnniversaries
  }
}

/// 예약할 알림 하나.
public struct PlannedReminder: Hashable, Sendable {
  public let dDayID: UUID
  public let daysBefore: Int
  /// 알림이 가리키는 날짜 (알림 문구용): 디데이 날짜 또는 기념일 날짜
  public let eventDay: CalendarDay
  /// 알림을 울릴 날짜
  public let day: CalendarDay
  public let time: TimeOfDay
  /// 기념일 알림이면 그 기념일 (알림 문구용: "100일", "1주년").
  /// nil = 디데이 날짜 자체 (dDay 방식의 목표일, D+·1일째 방식의 시작일).
  public let milestone: Milestone?

  public init(
    dDayID: UUID,
    daysBefore: Int,
    eventDay: CalendarDay,
    day: CalendarDay,
    time: TimeOfDay,
    milestone: Milestone?
  ) {
    self.dDayID = dDayID
    self.daysBefore = daysBefore
    self.eventDay = eventDay
    self.day = day
    self.time = time
    self.milestone = milestone
  }
}

/// 디데이 목록에서 예약할 로컬 알림을 고른다 (순수 로직). iOS 예약 한도 64개라 가까운 순 최대 60개만 고르고,
/// 앱 실행·복귀·디데이 변경 때 다시 계산한다 (PRODUCT §2).
/// - dDay 방식: 목표일에 알린다 (매년 반복이면 다음 날짜 `yearlyOccurrenceCount` 번).
/// - D+·1일째 방식: 시작일(오늘 이후면)과 기념일(100일 단위·N주년, 디데이마다 켜고 끔)에 알린다. 반복 규칙은 보지 않는다.
public enum NotificationPlanner {
  public static let maximumCount = 60
  /// 매년 반복하는 dDay 방식 디데이의 다음 날짜, 그리고 N주년 기념일을 이만큼까지 알린다.
  public static let yearlyOccurrenceCount = 2
  /// 100일 단위 기념일을 이만큼까지 알린다.
  public static let hundredDayOccurrenceCount = 2

  /// - dDay 방식: 다음 목표일(매년이면 `yearlyOccurrenceCount` 번)마다 N일 전 알림. 기념일 토글은 보지 않는다.
  /// - D+·1일째 방식: 시작일이 오늘 이후(오늘 포함)면 시작일 N일 전 알림(반복 규칙은 보지 않는다).
  ///   켜진 기념일은 N일 전마다 알림 날짜가 오늘 이후인 다음 기념일을 종류별로 2번까지 (기준 = 오늘 + N일).
  ///   같은 N 에서 100일 단위와 N주년이 같은 날이면 N주년 하나만 둔다.
  /// - 지난 알림과 오늘이면서 시각이 `now` 이하인 알림은 뺀다.
  /// - 날짜 → 시각 → 디데이 id → 며칠 전 순으로 정렬해 `limit` 개로 자른다.
  public static func plan(
    _ sources: [ReminderSource],
    today: CalendarDay,
    now: TimeOfDay,
    limit: Int = maximumCount
  ) -> [PlannedReminder] {
    var reminders = sources.flatMap { self.candidates(of: $0, today: today) }
    reminders.removeAll { $0.day < today || ($0.day == today && $0.time <= now) }
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

  /// 디데이 하나의 알림 후보 (지난 알림을 빼기 전).
  private static func candidates(of source: ReminderSource, today: CalendarDay) -> [PlannedReminder] {
    let offsets = Set(source.daysBefore.filter { $0 >= 0 })
    func reminder(_ eventDay: CalendarDay, _ offset: Int, _ milestone: Milestone?) -> PlannedReminder? {
      eventDay.adding(days: -offset).map { day in
        PlannedReminder(
          dDayID: source.dDayID,
          daysBefore: offset,
          eventDay: eventDay,
          day: day,
          time: source.time,
          milestone: milestone
        )
      }
    }
    let schedule = source.schedule
    guard schedule.countingStyle != .dDay else {
      let events = DDayCalculator.occurrences(
        of: schedule,
        onOrAfter: today,
        limit: schedule.repeatRule == .yearly ? self.yearlyOccurrenceCount : 1
      )
      return events.flatMap { eventDay in offsets.compactMap { reminder(eventDay, $0, nil) } }
    }
    var result: [PlannedReminder] = []
    if let start = DDayCalculator.originalDay(of: schedule.date), start >= today {
      result += offsets.compactMap { reminder(start, $0, nil) }
    }
    for offset in offsets {
      result += self.milestones(of: source, onOrAfter: today.adding(days: offset)).compactMap {
        reminder($0.day, offset, $0.milestone)
      }
    }
    return result
  }

  /// 켜진 기념일 중 `base` 를 포함해 그 뒤의 것을 종류별로 정해진 개수까지. 100일 단위가 N주년과 같은 날이면 뺀다.
  /// `base` 가 표현 범위 밖(nil)이면 [].
  private static func milestones(of source: ReminderSource, onOrAfter base: CalendarDay?) -> [MilestoneDay] {
    guard let base else { return [] }
    let years = source.remindsAnniversaries
      ? DDayCalculator.anniversaries(of: source.schedule, onOrAfter: base, limit: self.yearlyOccurrenceCount)
      : []
    guard source.remindsEveryHundredDays else { return years }
    let yearDays = Set(years.map(\.day))
    let hundreds = DDayCalculator.hundredDayMilestones(
      of: source.schedule,
      onOrAfter: base,
      limit: self.hundredDayOccurrenceCount
    )
    return years + hundreds.filter { !yearDays.contains($0.day) }
  }
}
