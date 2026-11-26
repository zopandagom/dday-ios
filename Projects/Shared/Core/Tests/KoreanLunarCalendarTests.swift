import Testing
@testable import Core

/// 기대값은 korean-lunar-calendar 0.3.1(한국천문연구원 기준)로 확인한 값이다.
struct KoreanLunarCalendarTests {
  @Test("음력 → 양력", arguments: [
    (LunarDate(year: 2025, month: 1, day: 1), CalendarDay(unchecked: 2025, 1, 29)),
    (LunarDate(year: 2025, month: 8, day: 15), CalendarDay(unchecked: 2025, 10, 6)),
    (LunarDate(year: 2026, month: 1, day: 1), CalendarDay(unchecked: 2026, 2, 17)),
    // 중국 춘절(2/6)과 다른 해
    (LunarDate(year: 2027, month: 1, day: 1), CalendarDay(unchecked: 2027, 2, 7)),
    (LunarDate(year: 2023, month: 2, day: 1, isLeapMonth: true), CalendarDay(unchecked: 2023, 3, 22)),
    (LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true), CalendarDay(unchecked: 2025, 7, 25)),
    (LunarDate(year: 2027, month: 8, day: 15), CalendarDay(unchecked: 2027, 9, 15)),
    (LunarDate(year: 2026, month: 10, day: 7), CalendarDay(unchecked: 2026, 11, 15)),
    (LunarDate(year: 2027, month: 10, day: 7), CalendarDay(unchecked: 2027, 11, 4)),
    // 음력 연도와 양력 연도가 다른 날
    (LunarDate(year: 2026, month: 12, day: 30), CalendarDay(unchecked: 2027, 2, 6)),
    (LunarDate(year: 2027, month: 12, day: 30), CalendarDay(unchecked: 2028, 1, 26)),
    (LunarDate(year: 2027, month: 1, day: 29), CalendarDay(unchecked: 2027, 3, 7)),
    (LunarDate(year: 2026, month: 6, day: 1), CalendarDay(unchecked: 2026, 7, 14)),
  ])
  func lunarToSolar(lunar: LunarDate, expected: CalendarDay) {
    #expect(KoreanLunarCalendar.solarDay(from: lunar) == expected)
  }

  @Test("양력 → 음력", arguments: [
    (CalendarDay(unchecked: 2026, 11, 26), LunarDate(year: 2026, month: 10, day: 18)),
    (CalendarDay(unchecked: 2027, 1, 1), LunarDate(year: 2026, month: 11, day: 24)),
    (CalendarDay(unchecked: 2023, 3, 22), LunarDate(year: 2023, month: 2, day: 1, isLeapMonth: true)),
    (CalendarDay(unchecked: 2023, 3, 21), LunarDate(year: 2023, month: 2, day: 30)),
  ])
  func solarToLunar(solar: CalendarDay, expected: LunarDate) {
    #expect(KoreanLunarCalendar.lunarDate(from: solar) == expected)
  }

  @Test("그해에 없는 윤달·날짜는 nil", arguments: [
    // 2026년은 윤달이 없다
    LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true),
    // 2025년 윤달은 6월뿐이다
    LunarDate(year: 2025, month: 5, day: 1, isLeapMonth: true),
    // 2027년 음력 1월은 29일까지다
    LunarDate(year: 2027, month: 1, day: 30),
    LunarDate(year: 2026, month: 13, day: 1),
    LunarDate(year: 2026, month: 1, day: 0),
  ])
  func invalidLunarDate(lunar: LunarDate) {
    #expect(KoreanLunarCalendar.solarDay(from: lunar) == nil)
  }

  @Test("윤달과 달의 일수를 알려 준다")
  func monthInfo() {
    #expect(KoreanLunarCalendar.leapMonth(in: 2023) == 2)
    #expect(KoreanLunarCalendar.leapMonth(in: 2025) == 6)
    #expect(KoreanLunarCalendar.leapMonth(in: 2026) == nil)
    #expect(KoreanLunarCalendar.numberOfDays(year: 2027, month: 1) == 29)
    #expect(KoreanLunarCalendar.numberOfDays(year: 2026, month: 12) == 30)
    #expect(KoreanLunarCalendar.numberOfDays(year: 2026, month: 6, isLeapMonth: true) == nil)
    #expect(KoreanLunarCalendar.numberOfDays(year: 1899, month: 1) == nil)
  }

  @Test("표 범위 경계: 양력 1900-01-31 ~ 2050-12-31")
  func bounds() {
    #expect(KoreanLunarCalendar.lunarDate(from: CalendarDay(unchecked: 1900, 1, 31)) == LunarDate(
      year: 1900,
      month: 1,
      day: 1
    ))
    #expect(KoreanLunarCalendar.lunarDate(from: CalendarDay(unchecked: 1900, 1, 30)) == nil)
    #expect(KoreanLunarCalendar.lunarDate(from: CalendarDay(unchecked: 2050, 12, 31)) == LunarDate(
      year: 2050,
      month: 11,
      day: 18
    ))
    #expect(KoreanLunarCalendar.lunarDate(from: CalendarDay(unchecked: 2051, 1, 1)) == nil)
    #expect(KoreanLunarCalendar.solarDay(from: LunarDate(year: 2050, month: 11, day: 19)) == nil)
    #expect(KoreanLunarCalendar.solarDay(from: LunarDate(year: 1899, month: 12, day: 1)) == nil)
    #expect(KoreanLunarCalendar.solarDay(from: LunarDate(year: 2051, month: 1, day: 1)) == nil)
  }

  @Test("표 범위 모든 날짜에서 양력 → 음력 → 양력이 같고 하루씩 이어진다")
  func roundTripWholeRange() throws {
    let range = KoreanLunarCalendar.supportedSolarRange
    var day = range.lowerBound
    var previous: LunarDate?
    while day <= range.upperBound {
      let lunar = try #require(KoreanLunarCalendar.lunarDate(from: day))
      #expect(KoreanLunarCalendar.solarDay(from: lunar) == day)
      if let previous {
        // 음력도 하루씩 이어진다: 같은 달이면 하루 뒤, 아니면 다음 달(또는 윤달) 1일
        let sameMonth = previous.year == lunar.year && previous.month == lunar.month
          && previous.isLeapMonth == lunar.isLeapMonth
        #expect(sameMonth ? lunar.day == previous.day + 1 : (lunar.day == 1 && (29 ... 30).contains(previous.day)))
      }
      previous = lunar
      day = try #require(day.adding(days: 1))
    }
  }

  @Test("표의 연도 간 설날 간격이 그해 달 일수의 합과 같다")
  func tableConsistency() {
    for (entry, next) in zip(KoreanLunarCalendar.table, KoreanLunarCalendar.table.dropFirst()) {
      let monthCount = entry.leapMonth > 0 ? 13 : 12
      let total = (0 ..< monthCount).reduce(0) { $0 + ((entry.monthSizeBits >> $1) & 1 == 1 ? 30 : 29) }
      #expect(next.newYear.days(from: entry.newYear) == total, "음력 \(entry.year)년")
      #expect(next.year == entry.year + 1)
    }
    #expect(KoreanLunarCalendar.table.count == 151)
  }
}
