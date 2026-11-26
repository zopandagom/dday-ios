import Core

/// 음력 선택기의 선택지와 맞춤 규칙 (순수).
/// "고를 수 있나"는 모두 `KoreanLunarCalendar.solarDay(from:) != nil` 로만 판단한다.
/// 표의 일수·윤달(`numberOfDays`·`leapMonth(in:)`)만으로는 변환 범위 끝(음력 2050-11-18) 뒤의 날을 걸러 내지 못한다.
enum LunarPickerOptions {
  struct Choices: Equatable {
    /// 표의 음력 연도 (1900...2050).
    let years: ClosedRange<Int>
    /// 그해 1일을 고를 수 있는 평달.
    let months: [Int]
    /// 그해 윤달 중 1일을 고를 수 있는 것. 없으면 nil.
    let leapMonth: Int?
    /// 지금 (연, 월, 윤달)에서 고를 수 있는 날.
    let days: ClosedRange<Int>
  }

  static let years = KoreanLunarCalendar.supportedLunarYears

  /// `lunar` 는 고를 수 있는 값이어야 한다.
  static func choices(for lunar: LunarDate) -> Choices {
    let lastDay = self.lastDay(year: lunar.year, month: lunar.month, isLeapMonth: lunar.isLeapMonth) ?? 1
    return Choices(
      years: self.years,
      months: self.months(in: lunar.year),
      leapMonth: self.leapMonth(in: lunar.year),
      days: 1 ... lastDay
    )
  }

  static func months(in year: Int) -> [Int] {
    (1 ... 12).filter { self.isSelectable(year: year, month: $0, isLeapMonth: false, day: 1) }
  }

  static func leapMonth(in year: Int) -> Int? {
    guard let month = KoreanLunarCalendar.leapMonth(in: year),
          self.isSelectable(year: year, month: month, isLeapMonth: true, day: 1)
    else {
      return nil
    }
    return month
  }

  /// 고를 수 있는 가장 큰 날. 그 달 1일도 고를 수 없으면 nil.
  static func lastDay(year: Int, month: Int, isLeapMonth: Bool) -> Int? {
    let tableDays = KoreanLunarCalendar.numberOfDays(year: year, month: month, isLeapMonth: isLeapMonth) ?? 30
    return (1 ... min(tableDays, 30)).reversed().first {
      self.isSelectable(year: year, month: month, isLeapMonth: isLeapMonth, day: $0)
    }
  }

  /// 고를 수 있는 값으로 맞춘다. 늘 성공한다.
  /// 1. 연을 표 범위로. 2. 월을 1...12 로 맞춘 뒤 그해에 없으면 그보다 작은 것 중 가장 큰 달.
  /// 3. 그해 윤달이 그 달일 때만 윤달. 4. 일을 1...마지막 날로.
  static func normalized(year: Int, month: Int, isLeapMonth: Bool, day: Int) -> LunarDate {
    let year = min(max(year, self.years.lowerBound), self.years.upperBound)
    let requestedMonth = min(max(month, 1), 12)
    let months = self.months(in: year)
    let month = months.last { $0 <= requestedMonth } ?? months.first ?? 1
    let isLeapMonth = isLeapMonth && self.leapMonth(in: year) == month
    let lastDay = self.lastDay(year: year, month: month, isLeapMonth: isLeapMonth) ?? 1
    return LunarDate(year: year, month: month, day: max(1, min(day, lastDay)), isLeapMonth: isLeapMonth)
  }

  private static func isSelectable(year: Int, month: Int, isLeapMonth: Bool, day: Int) -> Bool {
    KoreanLunarCalendar.solarDay(from: LunarDate(year: year, month: month, day: day, isLeapMonth: isLeapMonth)) != nil
  }
}
