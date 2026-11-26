import Testing
@testable import Core

struct MilestoneTests {
  private let today = CalendarDay(unchecked: 2026, 11, 26)

  private func solar(_ year: Int, _ month: Int, _ day: Int, _ style: CountingStyle = .dPlus) -> DDaySchedule {
    DDaySchedule(date: .solar(CalendarDay(unchecked: year, month, day)), countingStyle: style)
  }

  private func lunar(_ year: Int, _ month: Int, _ day: Int, leap: Bool = false) -> DDaySchedule {
    DDaySchedule(date: .lunar(LunarDate(year: year, month: month, day: day, isLeapMonth: leap)), countingStyle: .dPlus)
  }

  // MARK: - 100일 단위

  @Test(
    "100일 단위는 화면 숫자를 따른다: D+ 는 시작일+n, 1일째는 시작일+n−1",
    arguments: [
      (CountingStyle.dPlus, CalendarDay(unchecked: 2026, 8, 18)),
      (CountingStyle.dayOne, CalendarDay(unchecked: 2026, 8, 19)),
    ]
  )
  func hundredDaysFollowDisplayedNumber(style: CountingStyle, start: CalendarDay) {
    let schedule = DDaySchedule(date: .solar(start), countingStyle: style)
    #expect(DDayCalculator.hundredDayMilestones(of: schedule, onOrAfter: start, limit: 2) == [
      MilestoneDay(milestone: .hundredDays(100), day: CalendarDay(unchecked: 2026, 11, 26)),
      MilestoneDay(milestone: .hundredDays(200), day: CalendarDay(unchecked: 2027, 3, 6)),
    ])
  }

  @Test("기준일이 기념일 당일이면 포함하고, 다음 날이면 다음 기념일부터")
  func hundredDaysIncludeOnOrAfterDay() {
    let schedule = self.solar(2026, 8, 18)
    let onDay = DDayCalculator.hundredDayMilestones(of: schedule, onOrAfter: self.today, limit: 1)
    #expect(onDay == [MilestoneDay(milestone: .hundredDays(100), day: self.today)])
    let nextDay = DDayCalculator.hundredDayMilestones(
      of: schedule,
      onOrAfter: CalendarDay(unchecked: 2026, 11, 27),
      limit: 1
    )
    #expect(nextDay == [MilestoneDay(milestone: .hundredDays(200), day: CalendarDay(unchecked: 2027, 3, 6))])
  }

  @Test("시작일이 미래여도 첫 기념일은 100 (시작일 자체는 기념일이 아니다)")
  func hundredDaysOfFutureStartBeginAtHundred() {
    let milestones = DDayCalculator.hundredDayMilestones(of: self.solar(2026, 12, 25), onOrAfter: self.today, limit: 1)
    #expect(milestones == [MilestoneDay(milestone: .hundredDays(100), day: CalendarDay(unchecked: 2027, 4, 4))])
  }

  @Test("날짜 표현 범위를 넘으면 그 앞까지만")
  func hundredDaysStopAtMaximumDay() {
    let nearEnd = DDayCalculator.hundredDayMilestones(of: self.solar(9999, 9, 1), onOrAfter: self.today, limit: 2)
    #expect(nearEnd == [MilestoneDay(milestone: .hundredDays(100), day: CalendarDay(unchecked: 9999, 12, 10))])
    #expect(DDayCalculator.hundredDayMilestones(of: self.solar(9999, 10, 1), onOrAfter: self.today, limit: 2).isEmpty)
  }

  // MARK: - N주년

  @Test("N주년은 세는 방식과 상관없이 시작일과 같은 날짜", arguments: [CountingStyle.dPlus, .dayOne])
  func anniversariesUseSameDate(style: CountingStyle) {
    let schedule = self.solar(2020, 12, 25, style)
    #expect(DDayCalculator.anniversaries(of: schedule, onOrAfter: self.today, limit: 2) == [
      MilestoneDay(milestone: .years(6), day: CalendarDay(unchecked: 2026, 12, 25)),
      MilestoneDay(milestone: .years(7), day: CalendarDay(unchecked: 2027, 12, 25)),
    ])
  }

  @Test("2/29 시작은 평년 2/28, 윤년 2/29")
  func anniversaryOfFeb29() {
    #expect(DDayCalculator.anniversaries(of: self.solar(2024, 2, 29), onOrAfter: self.today, limit: 2) == [
      MilestoneDay(milestone: .years(3), day: CalendarDay(unchecked: 2027, 2, 28)),
      MilestoneDay(milestone: .years(4), day: CalendarDay(unchecked: 2028, 2, 29)),
    ])
  }

  @Test("음력 윤달 시작은 윤달이 없는 해에 평달 날짜")
  func lunarAnniversaryOfLeapMonth() {
    let schedule = self.lunar(2025, 6, 29, leap: true)
    #expect(DDayCalculator.anniversaries(
      of: schedule,
      onOrAfter: CalendarDay(unchecked: 2026, 1, 1),
      limit: 2
    ) == [
      MilestoneDay(milestone: .years(1), day: CalendarDay(unchecked: 2026, 8, 11)),
      MilestoneDay(milestone: .years(2), day: CalendarDay(unchecked: 2027, 8, 1)),
    ])
    let third = DDayCalculator.anniversaries(of: schedule, onOrAfter: CalendarDay(unchecked: 2027, 9, 1), limit: 1)
    #expect(third == [MilestoneDay(milestone: .years(3), day: CalendarDay(unchecked: 2028, 8, 19))])
  }

  @Test("음력 표 범위를 넘으면 그 앞까지만")
  func lunarAnniversaryStopsAtTableEnd() {
    #expect(DDayCalculator.anniversaries(of: self.lunar(2049, 11, 20), onOrAfter: self.today, limit: 2).isEmpty)
    #expect(DDayCalculator.anniversaries(of: self.lunar(2049, 11, 18), onOrAfter: self.today, limit: 2) == [
      MilestoneDay(milestone: .years(1), day: CalendarDay(unchecked: 2050, 12, 31)),
    ])
  }

  // MARK: - 없음

  @Test(
    "D-day 방식이나 시작일을 구할 수 없는 디데이는 기념일이 없다",
    arguments: [
      DDaySchedule(date: .solar(CalendarDay(unchecked: 2020, 12, 25)), countingStyle: .dDay),
      DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)), countingStyle: .dPlus),
      DDaySchedule(date: .lunar(LunarDate(year: 2051, month: 1, day: 1)), countingStyle: .dPlus),
      DDaySchedule(date: .lunar(LunarDate(year: .max, month: 1, day: 1)), countingStyle: .dayOne),
    ]
  )
  func noMilestonesForDDayOrUnavailableStart(schedule: DDaySchedule) {
    #expect(DDayCalculator.hundredDayMilestones(of: schedule, onOrAfter: self.today, limit: 2).isEmpty)
    #expect(DDayCalculator.anniversaries(of: schedule, onOrAfter: self.today, limit: 2).isEmpty)
  }

  @Test("개수가 0 이하면 빈 목록", arguments: [0, -1])
  func nonPositiveLimitIsEmpty(limit: Int) {
    let schedule = self.solar(2020, 12, 25)
    #expect(DDayCalculator.hundredDayMilestones(of: schedule, onOrAfter: self.today, limit: limit).isEmpty)
    #expect(DDayCalculator.anniversaries(of: schedule, onOrAfter: self.today, limit: limit).isEmpty)
  }
}
