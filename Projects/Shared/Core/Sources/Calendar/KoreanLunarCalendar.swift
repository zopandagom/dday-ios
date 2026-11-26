/// 한국천문연구원 기준 음력 ↔ 양력 변환. 표(`KoreanLunarTable.swift`) 범위는
/// 양력 1900-01-31(음력 1900-01-01) ~ 2050-12-31(음력 2050-11-18) 이고, 범위 밖이면 `nil` 을 돌려준다.
/// Foundation 의 `.chinese` 달력은 중국 기준이라 한국 날짜와 다른 해가 있어 쓰지 않는다.
public enum KoreanLunarCalendar {
  /// 변환할 수 있는 양력 범위. 상한은 원본 데이터(korean-lunar-calendar)가 검증한 범위를 따른다.
  public static let supportedSolarRange: ClosedRange<CalendarDay> =
    CalendarDay(unchecked: 1900, 1, 31) ... CalendarDay(unchecked: 2050, 12, 31)

  /// 표에 있는 음력 연도 범위. 2050년은 11월 18일까지만 변환한다.
  public static let supportedLunarYears: ClosedRange<Int> = 1900 ... 2050

  /// 음력 날짜를 양력으로. 그해에 없는 윤달·날짜(예: 29일까지인 달의 30일)이거나 범위 밖이면 `nil`.
  public static func solarDay(from lunar: LunarDate) -> CalendarDay? {
    guard let entry = self.entry(year: lunar.year),
          let offset = self.monthOffset(of: lunar, in: entry),
          let solar = entry.newYear.adding(days: offset + lunar.day - 1),
          self.supportedSolarRange.contains(solar)
    else {
      return nil
    }
    return solar
  }

  /// 양력 날짜를 음력으로. 범위 밖이면 `nil`.
  public static func lunarDate(from solar: CalendarDay) -> LunarDate? {
    guard self.supportedSolarRange.contains(solar),
          let entry = self.table.last(where: { $0.newYear <= solar })
    else {
      return nil
    }
    var remaining = solar.days(from: entry.newYear)
    for info in self.months(of: entry) {
      let (month, isLeap, days) = (info.month, info.isLeap, info.days)
      if remaining < days {
        return LunarDate(year: entry.year, month: month, day: remaining + 1, isLeapMonth: isLeap)
      }
      remaining -= days
    }
    return nil
  }

  /// 그해 윤달이 붙는 달. 윤달이 없거나 표 범위 밖이면 `nil`.
  /// 표의 사실(그해 윤달이 붙는 달)이다. 그 윤달을 고를 수 있는지(변환 범위 안인지)는 `solarDay(from:)` 로 확인한다.
  /// 2050년은 윤3월이 있다.
  public static func leapMonth(in year: Int) -> Int? {
    guard let entry = self.entry(year: year), entry.leapMonth > 0 else { return nil }
    return entry.leapMonth
  }

  /// 음력 `year` 년 `month` 월(윤달이면 `isLeapMonth`)의 일수(29 또는 30). 그런 달이 없으면 `nil`.
  /// 표의 사실(그 달의 일수)이다. 변환 범위 끝(음력 2050-11-18) 뒤의 날도 일수에 들어가므로
  /// (2050년 11월 30, 12월 29) 고를 수 있는지는 `solarDay(from:)` 로 확인한다.
  public static func numberOfDays(year: Int, month: Int, isLeapMonth: Bool = false) -> Int? {
    guard let entry = self.entry(year: year) else { return nil }
    return self.months(of: entry).first { $0.month == month && $0.isLeap == isLeapMonth }?.days
  }

  // MARK: - 표 해석

  private static func entry(year: Int) -> YearEntry? {
    guard self.supportedLunarYears.contains(year) else { return nil }
    return self.table[year - self.supportedLunarYears.lowerBound]
  }

  /// 그해 달 목록(윤달은 같은 번호 평달 바로 뒤)과 각 달의 일수.
  private static func months(of entry: YearEntry) -> [MonthInfo] {
    var result: [MonthInfo] = []
    for month in 1 ... 12 {
      result.append(MonthInfo(month: month, isLeap: false, days: 0))
      if month == entry.leapMonth {
        result.append(MonthInfo(month: month, isLeap: true, days: 0))
      }
    }
    for index in result.indices {
      result[index].days = (entry.monthSizeBits >> index) & 1 == 1 ? 30 : 29
    }
    return result
  }

  private struct MonthInfo {
    let month: Int
    let isLeap: Bool
    var days: Int
  }

  /// 음력 1월 1일부터 `lunar` 가 속한 달 1일까지의 일수. 그런 달이 없거나 날짜가 그 달에 없으면 `nil`.
  private static func monthOffset(of lunar: LunarDate, in entry: YearEntry) -> Int? {
    var offset = 0
    for info in self.months(of: entry) {
      let (month, isLeap, days) = (info.month, info.isLeap, info.days)
      if month == lunar.month, isLeap == lunar.isLeapMonth {
        return (1 ... days).contains(lunar.day) ? offset : nil
      }
      offset += days
    }
    return nil
  }
}
