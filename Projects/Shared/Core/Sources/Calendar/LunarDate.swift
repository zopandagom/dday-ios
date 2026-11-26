/// 한국 음력 날짜. 유효한지(그해에 그 윤달·그 날짜가 있는지)는 `KoreanLunarCalendar` 가 판단한다.
public struct LunarDate: Hashable, Sendable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int
  /// 윤달이면 `true`
  public let isLeapMonth: Bool

  public init(year: Int, month: Int, day: Int, isLeapMonth: Bool = false) {
    self.year = year
    self.month = month
    self.day = day
    self.isLeapMonth = isLeapMonth
  }

  public var description: String {
    "\(self.year)-\(self.month)-\(self.day)\(self.isLeapMonth ? " (윤)" : "")"
  }
}
