import Foundation
import Testing
@testable import Core

struct ReminderIdentifierTests {
  private let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()
  private let idB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B") ?? UUID()
  private let idC = UUID(uuidString: "00000000-0000-0000-0000-00000000000C") ?? UUID()
  private let idD = UUID(uuidString: "00000000-0000-0000-0000-00000000000D") ?? UUID()
  /// `NotificationPlannerMilestoneTests` 의 같은 날 100일·주년 픽스처 (2015-03-01 이 23주년이자 8400일).
  private let today = CalendarDay(unchecked: 2015, 2, 20)

  private func source(
    _ id: UUID,
    _ date: DDayDate,
    repeatRule: RepeatRule = .none,
    style: CountingStyle,
    hundred: Bool = false,
    years: Bool = false
  ) -> ReminderSource {
    ReminderSource(
      dDayID: id,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: style),
      daysBefore: [0, 2, 7, 30],
      time: .defaultReminderTime,
      remindsEveryHundredDays: hundred,
      remindsAnniversaries: years
    )
  }

  /// 매년 D-day + D+ 기념일 둘 다(같은 날 100일·주년 포함) + 1일째 시작일 미래(기념일 둘 다).
  private var mixedSources: [ReminderSource] {
    [
      self.source(self.idA, .solar(CalendarDay(unchecked: 2010, 3, 5)), repeatRule: .yearly, style: .dDay),
      self.source(self.idB, .solar(CalendarDay(unchecked: 1992, 3, 1)), style: .dPlus, hundred: true, years: true),
      self.source(self.idC, .solar(CalendarDay(unchecked: 2015, 3, 10)), style: .dayOne, hundred: true, years: true),
      self.source(self.idD, .solar(CalendarDay(unchecked: 2014, 6, 1)), style: .dayOne, hundred: true, years: true),
    ]
  }

  @Test("형식은 dday.reminder.<디데이 id>.<가리키는 날짜>.<N일 전>")
  func format() {
    let reminder = PlannedReminder(
      dDayID: self.idA,
      daysBefore: 7,
      eventDay: CalendarDay(unchecked: 2027, 3, 14),
      day: CalendarDay(unchecked: 2027, 3, 7),
      time: .defaultReminderTime,
      milestone: nil
    )
    #expect(reminder.identifier == "dday.reminder.00000000-0000-0000-0000-00000000000A.2027-03-14.7")
  }

  @Test("같은 입력을 두 번 계획하면 식별자가 같다")
  func stable() throws {
    let now = try #require(TimeOfDay(hour: 8, minute: 0))
    let first = NotificationPlanner.plan(self.mixedSources, today: self.today, now: now).map(\.identifier)
    let second = NotificationPlanner.plan(self.mixedSources.reversed(), today: self.today, now: now).map(\.identifier)
    #expect(!first.isEmpty)
    #expect(first == second)
  }

  @Test("섞인 소스의 계획 결과에서 식별자가 모두 다르다")
  func unique() throws {
    let now = try #require(TimeOfDay(hour: 8, minute: 0))
    let plan = NotificationPlanner.plan(self.mixedSources, today: self.today, now: now, limit: 1000)
    let ids = plan.map(\.identifier)
    #expect(Set(ids).count == ids.count)
    // 확인 범위: 목표일·시작일·100일 단위·주년이 모두 들어 있고, 같은 날 100일·주년 픽스처가 주년으로 들어 있다.
    #expect(plan.contains { $0.dDayID == self.idA && $0.milestone == nil })
    #expect(plan.contains { $0.dDayID == self.idC && $0.milestone == nil })
    #expect(plan.contains { $0.milestone == .hundredDays(8500) })
    #expect(plan.contains { $0.dDayID == self.idB && $0.milestone == .years(23) })
    #expect(!plan.contains { $0.dDayID == self.idB && $0.milestone == .hundredDays(8400) })
    #expect(Set(plan.map(\.daysBefore)) == [0, 2, 7, 30])
  }
}
