import Foundation
import Testing
@testable import Core

struct CalendarDayTests {
  @Test("없는 날짜는 만들지 않는다", arguments: [(2025, 2, 29), (2026, 4, 31), (2026, 13, 1), (2026, 0, 1), (0, 1, 1)])
  func invalidDate(year: Int, month: Int, day: Int) {
    #expect(CalendarDay(year: year, month: month, day: day) == nil)
  }

  @Test("윤년은 4년마다, 100년 단위는 400으로 나누어질 때만", arguments: [
    (1900, false), (2000, true), (2024, true), (2026, false), (2100, false),
  ])
  func leapYear(year: Int, expected: Bool) {
    #expect(CalendarDay.isLeapYear(year) == expected)
    #expect((CalendarDay(year: year, month: 2, day: 29) != nil) == expected)
  }

  @Test("알려진 율리우스 일과 맞는다", arguments: [
    (2000, 1, 1, 2_451_545), (1970, 1, 1, 2_440_588), (1900, 1, 31, 2_415_051), (1, 1, 1, 1_721_426),
  ])
  func julianDayNumber(year: Int, month: Int, day: Int, jdn: Int) throws {
    let calendarDay = try #require(CalendarDay(year: year, month: month, day: day))
    #expect(calendarDay.julianDayNumber == jdn)
    #expect(CalendarDay(julianDayNumber: jdn) == calendarDay)
  }

  @Test("율리우스 일 왕복이 1899~2101년 모든 날짜에서 같다")
  func julianDayRoundTrip() throws {
    let start = CalendarDay(unchecked: 1899, 1, 1).julianDayNumber
    let end = CalendarDay(unchecked: 2101, 12, 31).julianDayNumber
    var previous = try #require(CalendarDay(julianDayNumber: start - 1))
    for jdn in start ... end {
      let day = try #require(CalendarDay(julianDayNumber: jdn))
      #expect(day.julianDayNumber == jdn)
      #expect(CalendarDay(year: day.year, month: day.month, day: day.day) == day)
      #expect(previous < day)
      previous = day
    }
  }

  @Test("연도·윤년을 넘어 날짜를 더하고 뺀다")
  func addingDays() {
    #expect(CalendarDay(unchecked: 2026, 12, 31).adding(days: 1) == CalendarDay(unchecked: 2027, 1, 1))
    #expect(CalendarDay(unchecked: 2024, 2, 28).adding(days: 1) == CalendarDay(unchecked: 2024, 2, 29))
    #expect(CalendarDay(unchecked: 2025, 2, 28).adding(days: 1) == CalendarDay(unchecked: 2025, 3, 1))
    #expect(CalendarDay(unchecked: 2027, 1, 1).adding(days: -7) == CalendarDay(unchecked: 2026, 12, 25))
    #expect(CalendarDay(unchecked: 1, 1, 1).adding(days: -1) == nil)
  }

  @Test("표현 범위(1~9999년)를 넘거나 정수가 넘칠 만큼 더하면 멈추지 않고 nil")
  func outOfRange() {
    let today = CalendarDay(unchecked: 2026, 11, 26)
    #expect(CalendarDay(year: 10000, month: 1, day: 1) == nil)
    #expect(CalendarDay(year: .max, month: 1, day: 1) == nil)
    #expect(CalendarDay(julianDayNumber: .max) == nil)
    #expect(today.adding(days: .max) == nil)
    #expect(today.adding(days: .min) == nil)
    #expect(CalendarDay(unchecked: 9999, 12, 31).adding(days: 1) == nil)
    #expect(CalendarDay(julianDayNumber: CalendarDay.maximumJulianDayNumber) == CalendarDay(unchecked: 9999, 12, 31))
  }

  @Test("표현 범위 밖의 순간은 경계 날짜가 된다")
  func dateOutOfRange() throws {
    let utc = try #require(TimeZone(identifier: "UTC"))
    // 약 12650년
    #expect(CalendarDay(Date(timeIntervalSince1970: 337_000_000_000), in: utc) == CalendarDay(unchecked: 9999, 12, 31))
    #expect(CalendarDay(.distantPast, in: utc) == CalendarDay(unchecked: 1, 1, 1))
  }

  @Test("날짜 차이는 연도를 넘어도 일 단위로 정확하다")
  func daysBetween() {
    let today = CalendarDay(unchecked: 2026, 11, 26)
    #expect(CalendarDay(unchecked: 2027, 1, 1).days(from: today) == 36)
    #expect(today.days(from: CalendarDay(unchecked: 2027, 1, 1)) == -36)
    #expect(CalendarDay(unchecked: 2025, 1, 1).days(from: CalendarDay(unchecked: 2024, 1, 1)) == 366)
    #expect(today.days(from: today) == 0)
  }

  @Test("서머타임이 바뀌는 날을 지나도 하루 차이는 1이다")
  func daylightSavingTime() throws {
    let newYork = try #require(TimeZone(identifier: "America/New_York"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = newYork
    // 2026-03-08 02:00 에 서머타임 시작 (하루가 23시간)
    let before = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 30)))
    let after = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30)))
    let beforeDay = CalendarDay(before, in: newYork)
    let afterDay = CalendarDay(after, in: newYork)
    #expect(beforeDay == CalendarDay(unchecked: 2026, 3, 8))
    #expect(afterDay.days(from: beforeDay) == 1)
  }

  @Test("같은 순간이라도 시간대에 따라 그 시간대의 날짜가 된다")
  func timeZoneDate() throws {
    // 2026-11-25 15:30 UTC = 2026-11-26 00:30 서울
    let instant = Date(timeIntervalSince1970: 1_795_620_600)
    let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
    let utc = try #require(TimeZone(identifier: "UTC"))
    #expect(CalendarDay(instant, in: seoul) == CalendarDay(unchecked: 2026, 11, 26))
    #expect(CalendarDay(instant, in: utc) == CalendarDay(unchecked: 2026, 11, 25))
  }

  @Test("설명 문자열은 yyyy-MM-dd")
  func description() {
    #expect(CalendarDay(unchecked: 2027, 2, 7).description == "2027-02-07")
  }
}
