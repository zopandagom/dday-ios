import Foundation
import Testing
@testable import Core

struct DDayCalculatorTests {
  private let today = CalendarDay(unchecked: 2026, 11, 26)

  // MARK: - 다음 날짜

  @Test("반복 없음: 오늘 이후면 처음 날짜, 지났으면 없음")
  func noRepeat() {
    let upcoming = DDaySchedule(date: .solar(CalendarDay(unchecked: 2026, 12, 25)))
    let past = DDaySchedule(date: .solar(CalendarDay(unchecked: 2026, 11, 25)))
    let todayOnly = DDaySchedule(date: .solar(self.today))
    #expect(DDayCalculator.nextOccurrence(of: upcoming, onOrAfter: self.today) == CalendarDay(unchecked: 2026, 12, 25))
    #expect(DDayCalculator.nextOccurrence(of: past, onOrAfter: self.today) == nil)
    #expect(DDayCalculator.nextOccurrence(of: todayOnly, onOrAfter: self.today) == self.today)
    #expect(DDayCalculator.occurrences(of: upcoming, onOrAfter: self.today, limit: 3).count == 1)
  }

  @Test("양력 매년: 올해 지났으면 내년, 오늘이면 오늘")
  func solarYearly() {
    let christmas = DDaySchedule(date: .solar(CalendarDay(unchecked: 2020, 12, 25)), repeatRule: .yearly)
    #expect(DDayCalculator.nextOccurrence(of: christmas, onOrAfter: self.today) == CalendarDay(unchecked: 2026, 12, 25))
    #expect(
      DDayCalculator.nextOccurrence(of: christmas, onOrAfter: CalendarDay(unchecked: 2026, 12, 26))
        == CalendarDay(unchecked: 2027, 12, 25)
    )
    #expect(
      DDayCalculator.nextOccurrence(of: christmas, onOrAfter: CalendarDay(unchecked: 2026, 12, 25))
        == CalendarDay(unchecked: 2026, 12, 25)
    )
  }

  @Test("양력 매년: 처음 날짜보다 앞선 해는 만들지 않는다")
  func yearlyStartsAtOriginalYear() {
    let future = DDaySchedule(date: .solar(CalendarDay(unchecked: 2028, 3, 1)), repeatRule: .yearly)
    #expect(DDayCalculator.nextOccurrence(of: future, onOrAfter: self.today) == CalendarDay(unchecked: 2028, 3, 1))
  }

  @Test("양력 2/29 는 평년에 2/28, 윤년에 2/29")
  func leapDay() {
    let leapBirthday = DDaySchedule(date: .solar(CalendarDay(unchecked: 2024, 2, 29)), repeatRule: .yearly)
    #expect(
      DDayCalculator.occurrences(of: leapBirthday, onOrAfter: self.today, limit: 3) == [
        CalendarDay(unchecked: 2027, 2, 28),
        CalendarDay(unchecked: 2028, 2, 29),
        CalendarDay(unchecked: 2029, 2, 28),
      ]
    )
  }

  @Test("음력 매년: 그해 음력 날짜의 양력 날짜")
  func lunarYearly() {
    let chuseok = DDaySchedule(date: .lunar(LunarDate(year: 2025, month: 8, day: 15)), repeatRule: .yearly)
    #expect(
      DDayCalculator.occurrences(of: chuseok, onOrAfter: self.today, limit: 2) == [
        CalendarDay(unchecked: 2027, 9, 15),
        CalendarDay(unchecked: 2028, 10, 3),
      ]
    )
  }

  @Test("음력 매년: 지난 음력 연도의 날짜가 올해 양력에 오면 그것이 다음 날짜")
  func lunarYearCrossesSolarYear() {
    // 음력 2026-12-30 = 양력 2027-02-06
    let lunarNewYearEve = DDaySchedule(date: .lunar(LunarDate(year: 2020, month: 12, day: 30)), repeatRule: .yearly)
    #expect(
      DDayCalculator.nextOccurrence(of: lunarNewYearEve, onOrAfter: CalendarDay(unchecked: 2027, 1, 1))
        == CalendarDay(unchecked: 2027, 2, 6)
    )
  }

  @Test("음력 1/30 은 그해 1월이 29일까지면 1/29")
  func lunarMissingThirtieth() {
    let birthday = DDaySchedule(date: .lunar(LunarDate(year: 2000, month: 1, day: 30)), repeatRule: .yearly)
    #expect(DDayCalculator.occurrence(of: birthday.date, inYear: 2027) == CalendarDay(unchecked: 2027, 3, 7))
    #expect(
      DDayCalculator.nextOccurrence(of: birthday, onOrAfter: CalendarDay(unchecked: 2027, 3, 1))
        == CalendarDay(unchecked: 2027, 3, 7)
    )
  }

  @Test("음력 윤달 생일은 그해 윤달이 없으면 평달")
  func lunarLeapMonthFallback() {
    let leapBirthday = LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)
    #expect(DDayCalculator.occurrence(of: .lunar(leapBirthday), inYear: 2025) == CalendarDay(unchecked: 2025, 7, 25))
    #expect(DDayCalculator.occurrence(of: .lunar(leapBirthday), inYear: 2026) == CalendarDay(unchecked: 2026, 7, 14))
  }

  @Test("음력 매년: 표 범위를 넘으면 그 앞까지만")
  func lunarBeyondTable() {
    let newYear = DDaySchedule(date: .lunar(LunarDate(year: 2049, month: 1, day: 1)), repeatRule: .yearly)
    let result = DDayCalculator.occurrences(of: newYear, onOrAfter: CalendarDay(unchecked: 2049, 1, 1), limit: 5)
    #expect(result.count == 2)
    #expect(result.last.flatMap(KoreanLunarCalendar.lunarDate(from:)) == LunarDate(year: 2050, month: 1, day: 1))
  }

  @Test("limit 이 아주 커도 멈추지 않고 표현할 수 있는 해까지만")
  func hugeLimit() {
    let solar = DDaySchedule(date: .solar(CalendarDay(unchecked: 2020, 12, 25)), repeatRule: .yearly)
    let solarAll = DDayCalculator.occurrences(of: solar, onOrAfter: self.today, limit: .max)
    #expect(solarAll.first == CalendarDay(unchecked: 2026, 12, 25))
    #expect(solarAll.last == CalendarDay(unchecked: 9999, 12, 25))
    #expect(solarAll.count == 9999 - 2026 + 1)

    let lunar = DDaySchedule(date: .lunar(LunarDate(year: 2000, month: 1, day: 1)), repeatRule: .yearly)
    let lunarAll = DDayCalculator.occurrences(of: lunar, onOrAfter: self.today, limit: .max)
    #expect(lunarAll.first == CalendarDay(unchecked: 2027, 2, 7))
    #expect(lunarAll.count == 2050 - 2027 + 1)
  }

  @Test("잘못 저장된 아주 큰 연도도 멈추지 않고 날짜 없음")
  func hugeYear() {
    let lunar = DDaySchedule(date: .lunar(LunarDate(year: .max, month: 1, day: 1)), repeatRule: .yearly)
    #expect(DDayCalculator.occurrences(of: lunar, onOrAfter: self.today, limit: .max).isEmpty)
    #expect(DDayCalculator.dayCount(of: lunar, today: self.today) == nil)
    let plan = NotificationPlanner.plan(
      [
        ReminderSource(
          dDayID: UUID(),
          schedule: lunar,
          daysBefore: [0],
          time: .defaultReminderTime,
          remindsEveryHundredDays: true,
          remindsAnniversaries: true
        ),
      ],
      today: self.today,
      now: .defaultReminderTime
    )
    #expect(plan.isEmpty)
  }

  // MARK: - 세는 방식

  @Test("D-day: 남은 날, 당일 0, 지나면 음수")
  func dDayCount() {
    let christmas = DDaySchedule(date: .solar(CalendarDay(unchecked: 2026, 12, 25)))
    #expect(DDayCalculator.dayCount(of: christmas, today: self.today) == 29)
    #expect(DDayCalculator.dayCount(of: christmas, today: CalendarDay(unchecked: 2026, 12, 25)) == 0)
    #expect(DDayCalculator.dayCount(of: christmas, today: CalendarDay(unchecked: 2027, 1, 1)) == -7)
  }

  @Test("D-day 매년: 다음 날짜까지 남은 날")
  func dDayYearlyCount() {
    let christmas = DDaySchedule(date: .solar(CalendarDay(unchecked: 2020, 12, 25)), repeatRule: .yearly)
    #expect(DDayCalculator.dayCount(of: christmas, today: CalendarDay(unchecked: 2026, 12, 26)) == 364)
  }

  @Test("D+ 와 시작일=1일")
  func countingUp() {
    let start = DDaySchedule(date: .solar(CalendarDay(unchecked: 2026, 11, 20)), countingStyle: .dPlus)
    let dayOne = DDaySchedule(date: .solar(CalendarDay(unchecked: 2026, 11, 20)), countingStyle: .dayOne)
    #expect(DDayCalculator.dayCount(of: start, today: self.today) == 6)
    #expect(DDayCalculator.dayCount(of: dayOne, today: self.today) == 7)
    #expect(DDayCalculator.dayCount(of: dayOne, today: CalendarDay(unchecked: 2026, 11, 20)) == 1)
    // 연도를 넘어도 일 단위
    let lastYear = DDaySchedule(date: .solar(CalendarDay(unchecked: 2025, 11, 26)), countingStyle: .dayOne)
    #expect(DDayCalculator.dayCount(of: lastYear, today: self.today) == 366)
  }

  @Test("음력 날짜도 양력으로 바꿔 센다, 없는 음력 날짜면 nil")
  func lunarCount() {
    // 음력 2026-10-07 = 양력 2026-11-15
    let lunar = DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 10, day: 7)), countingStyle: .dPlus)
    #expect(DDayCalculator.dayCount(of: lunar, today: self.today) == 11)
    let invalid = DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)))
    #expect(DDayCalculator.dayCount(of: invalid, today: self.today) == nil)
  }
}
