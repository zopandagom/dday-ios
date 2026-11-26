/// 디데이 날짜: 양력 또는 한국 음력.
public enum DDayDate: Hashable, Sendable {
  case solar(CalendarDay)
  case lunar(LunarDate)
}

/// 반복 방식.
public enum RepeatRule: String, Hashable, Sendable, CaseIterable {
  /// 반복 없음
  case none
  /// 매년 같은 날(양력 또는 음력)
  case yearly
}

/// 날짜를 세는 방식.
public enum CountingStyle: String, Hashable, Sendable, CaseIterable {
  /// 남은 날: 목표일 - 오늘 (D-3 → 3, 당일 0, 지나면 음수)
  case dDay
  /// 지난 날: 오늘 - 시작일 (시작일 당일 0)
  case dPlus
  /// 시작일을 1일로 세기: 오늘 - 시작일 + 1 (시작일 당일 1)
  case dayOne
}

/// 디데이 하나의 날짜 규칙. D-day 계산기와 알림 계획기의 입력이다.
public struct DDaySchedule: Hashable, Sendable {
  public let date: DDayDate
  public let repeatRule: RepeatRule
  public let countingStyle: CountingStyle

  public init(date: DDayDate, repeatRule: RepeatRule = .none, countingStyle: CountingStyle = .dDay) {
    self.date = date
    self.repeatRule = repeatRule
    self.countingStyle = countingStyle
  }
}
