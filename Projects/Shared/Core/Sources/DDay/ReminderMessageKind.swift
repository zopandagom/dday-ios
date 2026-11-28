/// 알림 본문의 종류 (문구는 화면 쪽 String Catalog 가 정한다). `daysBefore` 0 = 당일.
public enum ReminderMessageKind: Hashable, Sendable {
  /// D-day 방식 목표일. 0 = 당일.
  case target(daysBefore: Int)
  /// D+·1일째 방식 시작일. 0 = 당일.
  case start(daysBefore: Int)
  /// D+ 방식 100일 단위 (D+n, n = 100, 200, …): "n일이 됐다".
  case daysSince(Int, daysBefore: Int)
  /// 1일째 방식 100일 단위 (n일째, n = 100, 200, …): "n일째 되는 날".
  case dayCount(Int, daysBefore: Int)
  /// N주년.
  case anniversary(years: Int, daysBefore: Int)
}

public extension PlannedReminder {
  /// 예약 식별자 `dday.reminder.<디데이 id>.<가리키는 날짜>.<N일 전>` (예: `dday.reminder.<UUID>.2027-03-14.7`).
  /// 같은 계획 결과면 늘 같고(시각·문구·순서와 무관), 계획기 출력 안에서는 겹치지 않는다
  /// ((디데이, 가리키는 날짜, N일 전) 이 겹치지 않는다: 같은 날의 100일·주년은 계획기가 주년 하나만 남긴다).
  /// 사용자 데이터(id·날짜)를 담으므로 로그에 쓰지 않는다.
  var identifier: String {
    "dday.reminder.\(self.dDayID.uuidString).\(self.eventDay.description).\(self.daysBefore)"
  }

  /// 본문 종류. 기념일이 없으면 dDay 방식은 목표일, 그 밖은 시작일. `.hundredDays(n)` 은 D+ 면 daysSince,
  /// 1일째면 dayCount (dDay 방식에는 오지 않는다. 오면 daysSince). `.years(n)` 은 anniversary.
  func messageKind(countingStyle: CountingStyle) -> ReminderMessageKind {
    switch self.milestone {
    case .none:
      if countingStyle == .dDay {
        return .target(daysBefore: self.daysBefore)
      }
      return .start(daysBefore: self.daysBefore)
    case let .hundredDays(number):
      if countingStyle == .dayOne {
        return .dayCount(number, daysBefore: self.daysBefore)
      }
      return .daysSince(number, daysBefore: self.daysBefore)
    case let .years(years):
      return .anniversary(years: years, daysBefore: self.daysBefore)
    }
  }
}
