import Foundation
import Testing
@testable import Core

struct ReminderMessageKindTests {
  private let idA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()

  private func planned(daysBefore: Int, milestone: Milestone?) -> PlannedReminder {
    PlannedReminder(
      dDayID: self.idA,
      daysBefore: daysBefore,
      eventDay: CalendarDay(unchecked: 2027, 3, 14),
      day: CalendarDay(unchecked: 2027, 3, 14).adding(days: -daysBefore) ?? CalendarDay(unchecked: 2027, 3, 14),
      time: .defaultReminderTime,
      milestone: milestone
    )
  }

  @Test("기념일이 없으면 dDay 방식은 목표일, D+·1일째 방식은 시작일", arguments: [0, 2, 7, 30])
  func withoutMilestone(daysBefore: Int) {
    let reminder = self.planned(daysBefore: daysBefore, milestone: nil)
    #expect(reminder.messageKind(countingStyle: .dDay) == .target(daysBefore: daysBefore))
    #expect(reminder.messageKind(countingStyle: .dPlus) == .start(daysBefore: daysBefore))
    #expect(reminder.messageKind(countingStyle: .dayOne) == .start(daysBefore: daysBefore))
  }

  @Test("100일 단위는 D+ 면 daysSince, 1일째면 dayCount (dDay 방식에 오면 daysSince)", arguments: [0, 7])
  func hundredDays(daysBefore: Int) {
    let reminder = self.planned(daysBefore: daysBefore, milestone: .hundredDays(200))
    #expect(reminder.messageKind(countingStyle: .dPlus) == .daysSince(200, daysBefore: daysBefore))
    #expect(reminder.messageKind(countingStyle: .dayOne) == .dayCount(200, daysBefore: daysBefore))
    #expect(reminder.messageKind(countingStyle: .dDay) == .daysSince(200, daysBefore: daysBefore))
  }

  @Test("N주년은 세는 방식과 상관없이 anniversary", arguments: CountingStyle.allCases)
  func anniversary(style: CountingStyle) {
    #expect(self.planned(daysBefore: 0, milestone: .years(3)).messageKind(countingStyle: style)
      == .anniversary(years: 3, daysBefore: 0))
    #expect(self.planned(daysBefore: 30, milestone: .years(3)).messageKind(countingStyle: style)
      == .anniversary(years: 3, daysBefore: 30))
  }
}
