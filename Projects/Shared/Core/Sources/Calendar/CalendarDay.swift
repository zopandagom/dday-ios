import Foundation

/// 시각·시간대 없는 양력(그레고리력) 날짜. 날짜 차이와 더하기는 율리우스 일(JDN)로 계산해
/// 시간대·서머타임에 영향을 받지 않는다.
public struct CalendarDay: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int

  /// 존재하는 날짜(1년 1월 1일 ~ 9999년 12월 31일)만 만든다. 2025-02-29 처럼 없는 날짜면 `nil`.
  public init?(year: Int, month: Int, day: Int) {
    guard (1 ... Self.maximumYear).contains(year), (1 ... 12).contains(month),
          (1 ... Self.numberOfDays(year: year, month: month)).contains(day)
    else {
      return nil
    }
    self.init(unchecked: year, month, day)
  }

  /// 이미 검증된 값(음력 표 등)으로 만든다.
  init(unchecked year: Int, _ month: Int, _ day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }

  /// 율리우스 일(JDN)에서 만든다. 1년 1월 1일(JDN 1721426) ~ 9999년 12월 31일(JDN 5373484) 밖이면 `nil`.
  public init?(julianDayNumber jdn: Int) {
    guard (Self.minimumJulianDayNumber ... Self.maximumJulianDayNumber).contains(jdn) else { return nil }
    let shifted = jdn + 32044
    let century = (4 * shifted + 3) / 146_097
    let dayOfCentury = shifted - 146_097 * century / 4
    let yearOfCentury = (4 * dayOfCentury + 3) / 1461
    let dayOfYear = dayOfCentury - 1461 * yearOfCentury / 4
    let monthIndex = (5 * dayOfYear + 2) / 153
    self.init(
      unchecked: 100 * century + yearOfCentury - 4800 + monthIndex / 10,
      monthIndex + 3 - 12 * (monthIndex / 10),
      dayOfYear - (153 * monthIndex + 2) / 5 + 1
    )
  }

  /// `date` 가 `timeZone` 에서 몇 년 몇 월 며칠인지로 만든다. 앱이 "오늘"을 구할 때만 쓴다.
  /// 표현 범위(1년 1월 1일 ~ 9999년 12월 31일) 밖의 순간은 가까운 경계 날짜가 된다.
  public init(_ date: Date, in timeZone: TimeZone) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
    let year = components.era == 0 ? 0 : (components.year ?? 1)
    if year < 1 {
      self.init(unchecked: 1, 1, 1)
    } else if year > Self.maximumYear {
      self.init(unchecked: Self.maximumYear, 12, 31)
    } else {
      self.init(unchecked: year, components.month ?? 1, components.day ?? 1)
    }
  }

  /// 표현하는 마지막 해. 계산 중 정수가 넘치지 않도록 범위를 막는다.
  public static let maximumYear = 9999
  static let minimumJulianDayNumber = 1_721_426
  static let maximumJulianDayNumber = 5_373_484

  /// 율리우스 일(JDN). 하루 차이가 정확히 1 이다.
  public var julianDayNumber: Int {
    let shift = (14 - self.month) / 12
    let shiftedYear = self.year + 4800 - shift
    let shiftedMonth = self.month + 12 * shift - 3
    let yearDays = 365 * shiftedYear + shiftedYear / 4 - shiftedYear / 100 + shiftedYear / 400
    return self.day + (153 * shiftedMonth + 2) / 5 + yearDays - 32045
  }

  /// `days` 일 뒤(음수면 앞)의 날짜. 표현 범위(1년 1월 1일 ~ 9999년 12월 31일) 밖이면 `nil`.
  public func adding(days: Int) -> CalendarDay? {
    let (jdn, overflow) = self.julianDayNumber.addingReportingOverflow(days)
    return overflow ? nil : CalendarDay(julianDayNumber: jdn)
  }

  /// `other` 에서 이 날짜까지의 일수. 이 날짜가 뒤면 양수.
  public func days(from other: CalendarDay) -> Int {
    self.julianDayNumber - other.julianDayNumber
  }

  public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  public var description: String {
    let month = self.month < 10 ? "0\(self.month)" : "\(self.month)"
    let day = self.day < 10 ? "0\(self.day)" : "\(self.day)"
    return "\(self.year)-\(month)-\(day)"
  }

  public static func isLeapYear(_ year: Int) -> Bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
  }

  /// 양력 `year` 년 `month` 월의 일수. `month` 가 1~12 밖이면 0.
  public static func numberOfDays(year: Int, month: Int) -> Int {
    switch month {
    case 1, 3, 5, 7, 8, 10, 12: 31
    case 4, 6, 9, 11: 30
    case 2: self.isLeapYear(year) ? 29 : 28
    default: 0
    }
  }
}
