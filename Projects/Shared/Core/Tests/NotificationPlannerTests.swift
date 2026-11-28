import Foundation
import Testing
@testable import Core

struct NotificationPlannerTests {
  private let today = CalendarDay(unchecked: 2026, 11, 26)
  private let nine = TimeOfDay.defaultReminderTime
  private let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
  private let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()

  private func time(_ hour: Int, _ minute: Int = 0) throws -> TimeOfDay {
    try #require(TimeOfDay(hour: hour, minute: minute))
  }

  private func source(
    _ id: UUID,
    _ date: DDayDate,
    repeatRule: RepeatRule = .none,
    style: CountingStyle = .dDay,
    daysBefore: [Int] = [7, 2, 0],
    time: TimeOfDay = .defaultReminderTime,
    hundred: Bool = false,
    years: Bool = false
  ) -> ReminderSource {
    ReminderSource(
      dDayID: id,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: style),
      daysBefore: daysBefore,
      time: time,
      remindsEveryHundredDays: hundred,
      remindsAnniversaries: years
    )
  }

  @Test("기본 7일 전·2일 전·당일 알림을 시간순으로 만든다")
  func defaultReminders() throws {
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 12, 25)))],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.map(\.day) == [
      CalendarDay(unchecked: 2026, 12, 18), CalendarDay(unchecked: 2026, 12, 23), CalendarDay(unchecked: 2026, 12, 25),
    ])
    #expect(plan.map(\.daysBefore) == [7, 2, 0])
    #expect(plan.allSatisfy { $0.dDayID == self.idA && $0.time == self.nine })
    #expect(plan.allSatisfy { $0.eventDay == CalendarDay(unchecked: 2026, 12, 25) })
    #expect(plan.allSatisfy { $0.milestone == nil })
  }

  @Test("지난 알림과 이미 시각이 지난 오늘 알림은 뺀다")
  func skipsPast() throws {
    // 2026-12-03: 7일 전 = 오늘 9:00
    let sources = [self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 12, 3)), daysBefore: [10, 7, 2, 0])]
    let afterNine = try NotificationPlanner.plan(sources, today: self.today, now: self.time(10))
    #expect(afterNine.map(\.daysBefore) == [2, 0])
    let atNine = try NotificationPlanner.plan(sources, today: self.today, now: self.time(9))
    #expect(atNine.map(\.daysBefore) == [2, 0])
    let beforeNine = try NotificationPlanner.plan(sources, today: self.today, now: self.time(8, 59))
    #expect(beforeNine.map(\.daysBefore) == [7, 2, 0])
  }

  @Test("지난 반복 없는 디데이는 알림이 없다")
  func pastDDay() throws {
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 11, 1)))],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.isEmpty)
  }

  @Test("D+·1일째 방식은 시작일이 오늘 이후면 시작일에 알린다", arguments: [CountingStyle.dPlus, .dayOne])
  func upcomingStartDayOfDPlusAndDayOne(style: CountingStyle) throws {
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 12, 25)), style: style)],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.map(\.day) == [
      CalendarDay(unchecked: 2026, 12, 18), CalendarDay(unchecked: 2026, 12, 23), CalendarDay(unchecked: 2026, 12, 25),
    ])
    #expect(plan.allSatisfy { $0.eventDay == CalendarDay(unchecked: 2026, 12, 25) && $0.milestone == nil })
  }

  @Test("D+·1일째 방식은 반복 규칙을 보지 않는다: 지난 시작일은 기념일로만 알린다")
  func passedStartIgnoresRepeatRule() throws {
    let date = DDayDate.solar(CalendarDay(unchecked: 2020, 12, 25))
    let off = try NotificationPlanner.plan(
      [self.source(self.idA, date, repeatRule: .yearly, style: .dayOne)],
      today: self.today,
      now: self.time(8)
    )
    #expect(off.isEmpty)
    let anniversaries = try NotificationPlanner.plan(
      [self.source(self.idA, date, repeatRule: .yearly, style: .dayOne, years: true)],
      today: self.today,
      now: self.time(8)
    )
    #expect(anniversaries.map(\.day) == [
      CalendarDay(unchecked: 2026, 12, 18), CalendarDay(unchecked: 2026, 12, 23), CalendarDay(unchecked: 2026, 12, 25),
      CalendarDay(unchecked: 2027, 12, 18), CalendarDay(unchecked: 2027, 12, 23), CalendarDay(unchecked: 2027, 12, 25),
    ])
    #expect(anniversaries.map(\.daysBefore) == [7, 2, 0, 7, 2, 0])
    #expect(anniversaries.map(\.milestone) == [
      .years(6), .years(6), .years(6), .years(7), .years(7), .years(7),
    ])
  }

  @Test("D-day 방식은 기념일 토글을 켜도 결과가 같다")
  func dDayStyleIgnoresMilestoneFlags() throws {
    let date = DDayDate.solar(CalendarDay(unchecked: 2020, 12, 25))
    let off = try NotificationPlanner.plan(
      [self.source(self.idA, date, repeatRule: .yearly)],
      today: self.today,
      now: self.time(8)
    )
    let withFlags = try NotificationPlanner.plan(
      [self.source(self.idA, date, repeatRule: .yearly, hundred: true, years: true)],
      today: self.today,
      now: self.time(8)
    )
    #expect(off.count == 6)
    #expect(withFlags == off)
    #expect(withFlags.allSatisfy { $0.milestone == nil })
  }

  @Test("매년 반복은 다음 날짜 2번까지")
  func yearlyTwoOccurrences() throws {
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, .lunar(LunarDate(year: 2000, month: 8, day: 15)), repeatRule: .yearly)],
      today: self.today,
      now: self.time(8)
    )
    #expect(Set(plan.map(\.eventDay)) == [CalendarDay(unchecked: 2027, 9, 15), CalendarDay(unchecked: 2028, 10, 3)])
    #expect(plan.count == 6)
  }

  @Test("음수·중복 '며칠 전'은 무시한다, 비어 있으면 알림 없음")
  func offsetsNormalized() throws {
    let date = DDayDate.solar(CalendarDay(unchecked: 2026, 12, 25))
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, date, daysBefore: [1, 1, -3]), self.source(self.idB, date, daysBefore: [])],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.map(\.daysBefore) == [1])
  }

  @Test("여러 디데이를 날짜 → 시각 → id 순으로 섞어 정렬한다")
  func ordering() throws {
    let plan = try NotificationPlanner.plan(
      [
        self.source(self.idB, .solar(CalendarDay(unchecked: 2026, 12, 1)), daysBefore: [0], time: self.time(8)),
        self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 12, 1)), daysBefore: [0], time: self.time(8)),
        self.source(self.idA, .solar(CalendarDay(unchecked: 2026, 12, 3)), daysBefore: [2], time: self.time(7)),
        self.source(self.idB, .solar(CalendarDay(unchecked: 2026, 11, 30)), daysBefore: [0]),
      ],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.map(\.day) == [
      CalendarDay(unchecked: 2026, 11, 30),
      CalendarDay(unchecked: 2026, 12, 1),
      CalendarDay(unchecked: 2026, 12, 1),
      CalendarDay(unchecked: 2026, 12, 1),
    ])
    #expect(try plan.dropFirst().map(\.time) == [self.time(7), self.time(8), self.time(8)])
    #expect(plan.suffix(2).map(\.dDayID) == [self.idA, self.idB])
  }

  @Test("가까운 순으로 최대 60개만")
  func limit() throws {
    // 40개 디데이 × 2번 × 3개 = 240개 (가장 이른 7일 전 알림도 오늘 이후)
    let sources = (0 ..< 40).map { index in
      self.source(
        UUID(),
        .solar(CalendarDay(unchecked: 2020, 12, 10).adding(days: index) ?? self.today),
        repeatRule: .yearly
      )
    }
    let plan = try NotificationPlanner.plan(sources, today: self.today, now: self.time(8))
    #expect(plan.count == NotificationPlanner.maximumCount)
    let all = try NotificationPlanner.plan(sources, today: self.today, now: self.time(8), limit: .max)
    #expect(all.count == 240)
    #expect(Array(all.prefix(60)) == plan)
    #expect(zip(plan, plan.dropFirst()).allSatisfy { $0.day <= $1.day })
  }

  @Test("30일 전 알림은 정확히 30일 전에 온다 (기념일도 같다)")
  func thirtyDaysBeforeIsExactlyThirtyDays() throws {
    let plan = try NotificationPlanner.plan(
      [self.source(self.idA, .solar(CalendarDay(unchecked: 2027, 3, 14)), daysBefore: [0, 2, 7, 30])],
      today: self.today,
      now: self.time(8)
    )
    #expect(plan.map(\.day) == [
      CalendarDay(unchecked: 2027, 2, 12), CalendarDay(unchecked: 2027, 3, 7),
      CalendarDay(unchecked: 2027, 3, 12), CalendarDay(unchecked: 2027, 3, 14),
    ])
    #expect(plan.map(\.daysBefore) == [30, 7, 2, 0])

    let milestones = try NotificationPlanner.plan(
      [self.source(
        self.idA,
        .solar(CalendarDay(unchecked: 2026, 8, 18)),
        style: .dPlus,
        daysBefore: [30],
        hundred: true
      )],
      today: self.today,
      now: self.time(8)
    )
    #expect(milestones.map(\.day) == [CalendarDay(unchecked: 2027, 2, 4), CalendarDay(unchecked: 2027, 5, 15)])
    #expect(milestones.map(\.milestone) == [.hundredDays(200), .hundredDays(300)])
  }

  @Test("시각은 0~23시, 0~59분만")
  func timeOfDayValidation() {
    #expect(TimeOfDay(hour: 24, minute: 0) == nil)
    #expect(TimeOfDay(hour: 9, minute: 60) == nil)
    #expect(TimeOfDay(hour: 23, minute: 59) != nil)
  }

  @Test("TimeOfDay(_:in:) 는 그 시간대의 시·분이고 초는 버린다")
  func timeOfDayFromDate() throws {
    // 2026-11-26 14:59:59 UTC = 서울 23:59:59
    let date = Date(timeIntervalSince1970: 1_795_705_199)
    let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
    let utc = try #require(TimeZone(identifier: "UTC"))
    try #expect(TimeOfDay(date, in: seoul) == self.time(23, 59))
    try #expect(TimeOfDay(date, in: utc) == self.time(14, 59))
    #expect(CalendarDay(date, in: seoul) == self.today)
    try #expect(TimeOfDay(Date(timeIntervalSince1970: 1_795_651_200), in: utc) == self.time(0))
  }
}
