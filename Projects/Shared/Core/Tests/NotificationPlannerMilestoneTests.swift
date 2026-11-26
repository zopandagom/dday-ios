import Foundation
import Testing
@testable import Core

/// D+·1일째 방식의 기념일 알림 (100일 단위·N주년).
struct NotificationPlannerMilestoneTests {
  private let today = CalendarDay(unchecked: 2026, 11, 26)
  private let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
  /// 오늘이 100일인 D+ 디데이
  private let hundredToday = DDayDate.solar(CalendarDay(unchecked: 2026, 8, 18))

  private func time(_ hour: Int) throws -> TimeOfDay {
    try #require(TimeOfDay(hour: hour, minute: 0))
  }

  private func source(
    _ date: DDayDate,
    id: UUID? = nil,
    style: CountingStyle = .dPlus,
    daysBefore: [Int] = [0],
    hundred: Bool,
    years: Bool
  ) -> ReminderSource {
    ReminderSource(
      dDayID: id ?? self.idA,
      schedule: DDaySchedule(date: date, countingStyle: style),
      daysBefore: daysBefore,
      time: .defaultReminderTime,
      remindsEveryHundredDays: hundred,
      remindsAnniversaries: years
    )
  }

  private func plan(
    _ sources: [ReminderSource],
    today: CalendarDay? = nil,
    now: TimeOfDay
  ) -> [PlannedReminder] {
    NotificationPlanner.plan(sources, today: today ?? self.today, now: now)
  }

  @Test("100일마다·매년 토글은 따로 켜고 끈다", arguments: [false, true], [false, true])
  func milestoneTogglesAreIndependent(hundred: Bool, years: Bool) throws {
    let plan = try self.plan([self.source(self.hundredToday, hundred: hundred, years: years)], now: self.time(8))
    var expected: [MilestoneDay] = []
    if hundred {
      expected += [
        MilestoneDay(milestone: .hundredDays(100), day: CalendarDay(unchecked: 2026, 11, 26)),
        MilestoneDay(milestone: .hundredDays(200), day: CalendarDay(unchecked: 2027, 3, 6)),
      ]
    }
    if years {
      expected += [
        MilestoneDay(milestone: .years(1), day: CalendarDay(unchecked: 2027, 8, 18)),
        MilestoneDay(milestone: .years(2), day: CalendarDay(unchecked: 2028, 8, 18)),
      ]
    }
    #expect(plan.map(\.day) == expected.map(\.day))
    #expect(plan.map(\.eventDay) == expected.map(\.day))
    #expect(plan.map(\.milestone) == expected.map(\.milestone))
  }

  @Test("오늘이 기념일이면 알림 시각이 지나지 않았을 때만 남는다")
  func milestoneTodayRespectsTime() throws {
    let sources = [self.source(self.hundredToday, hundred: true, years: true)]
    let beforeNine = try self.plan(sources, now: self.time(8))
    #expect(beforeNine.first?.day == self.today)
    #expect(beforeNine.first?.milestone == .hundredDays(100))
    for hour in [9, 10] {
      let afterNine = try self.plan(sources, now: self.time(hour))
      #expect(afterNine.first?.day == CalendarDay(unchecked: 2027, 3, 6))
      #expect(afterNine.first?.milestone == .hundredDays(200))
      #expect(afterNine.count == 3)
    }
  }

  @Test("N일 전이 100일보다 커도 알림 날짜가 오늘 이후인 다음 기념일 2번을 고른다")
  func largeDaysBeforeKeepsNextMilestones() throws {
    let plan = try self.plan(
      [self.source(self.hundredToday, daysBefore: [150], hundred: true, years: false)],
      now: self.time(8)
    )
    #expect(plan.map(\.day) == [CalendarDay(unchecked: 2027, 1, 15), CalendarDay(unchecked: 2027, 4, 25)])
    #expect(plan.map(\.eventDay) == [CalendarDay(unchecked: 2027, 6, 14), CalendarDay(unchecked: 2027, 9, 22)])
    #expect(plan.map(\.milestone) == [.hundredDays(300), .hundredDays(400)])
    #expect(plan.allSatisfy { $0.daysBefore == 150 })
  }

  @Test("100일 단위와 N주년이 같은 날이면 N주년 하나만, 주년을 끄면 100일이 남는다")
  func sameDayHundredAndAnniversaryBecomeOne() throws {
    let start = DDayDate.solar(CalendarDay(unchecked: 1992, 3, 1))
    let today = CalendarDay(unchecked: 2015, 2, 20)
    let both = try self.plan([self.source(start, hundred: true, years: true)], today: today, now: self.time(8))
    #expect(both.map(\.day) == [
      CalendarDay(unchecked: 2015, 3, 1), CalendarDay(unchecked: 2015, 6, 9), CalendarDay(unchecked: 2016, 3, 1),
    ])
    #expect(both.map(\.milestone) == [.years(23), .hundredDays(8500), .years(24)])
    let hundredOnly = try self.plan([self.source(start, hundred: true, years: false)], today: today, now: self.time(8))
    #expect(hundredOnly.first?.day == CalendarDay(unchecked: 2015, 3, 1))
    #expect(hundredOnly.first?.milestone == .hundredDays(8400))
  }

  @Test("1일째 방식의 100일은 같은 시작일의 D+ 100일보다 하루 앞")
  func dayOneHundredDaysOneDayEarlier() throws {
    let today = CalendarDay(unchecked: 2026, 11, 1)
    let dPlus = try self.plan(
      [self.source(self.hundredToday, hundred: true, years: false)],
      today: today,
      now: self.time(8)
    )
    let dayOne = try self.plan(
      [self.source(self.hundredToday, style: .dayOne, hundred: true, years: false)],
      today: today,
      now: self.time(8)
    )
    #expect(dPlus.first?.day == CalendarDay(unchecked: 2026, 11, 26))
    #expect(dayOne.first?.day == CalendarDay(unchecked: 2026, 11, 25))
    #expect(dayOne.first?.milestone == .hundredDays(100))
  }

  @Test("알림 날짜가 하나도 없으면 기념일 알림도 없다")
  func milestonesNeedEnabledDays() throws {
    let plan = try self.plan(
      [self.source(self.hundredToday, daysBefore: [], hundred: true, years: true)],
      now: self.time(8)
    )
    #expect(plan.isEmpty)
  }

  @Test("시작일을 구할 수 없는 디데이는 알림이 없다")
  func unavailableStartHasNoReminders() throws {
    let date = DDayDate.lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true))
    let plan = try self.plan([self.source(date, daysBefore: [7, 2, 0], hundred: true, years: true)], now: self.time(8))
    #expect(plan.isEmpty)
  }

  @Test("기념일 알림도 전체 60개 제한 안에서 가까운 순으로 잘린다")
  func milestonesShareGlobalLimit() throws {
    let ids = try (1 ... 20).map { number in
      try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-0000000000%02d", number)))
    }
    let sources = ids.map { self.source(self.hundredToday, id: $0, hundred: true, years: true) }
    let all = try NotificationPlanner.plan(sources, today: self.today, now: self.time(8), limit: .max)
    #expect(all.count == 80)
    let plan = try self.plan(sources, now: self.time(8))
    #expect(plan.count == NotificationPlanner.maximumCount)
    let groups: [(day: CalendarDay, milestone: Milestone)] = [
      (CalendarDay(unchecked: 2026, 11, 26), .hundredDays(100)),
      (CalendarDay(unchecked: 2027, 3, 6), .hundredDays(200)),
      (CalendarDay(unchecked: 2027, 8, 18), .years(1)),
    ]
    for (index, group) in groups.enumerated() {
      let slice = Array(plan[(index * 20) ..< ((index + 1) * 20)])
      #expect(slice.allSatisfy { $0.day == group.day && $0.milestone == group.milestone })
      #expect(slice.map(\.dDayID) == ids)
    }
    #expect(!plan.contains { $0.day == CalendarDay(unchecked: 2028, 8, 18) })
  }
}
