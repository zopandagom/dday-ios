/// 기념일. 숫자는 화면에 보이는 값이다. D+·1일째 방식 디데이에만 있다.
public enum Milestone: Hashable, Sendable {
  /// 100일 단위 (100, 200, …). D+ 는 시작일 + n 일 (D+n), 1일째는 시작일 + n − 1 일 (n일째).
  case hundredDays(Int)
  /// N주년 (1, 2, …). 시작일과 같은 날짜 (세는 방식과 상관없이).
  case years(Int)
}

/// 기념일과 그 날짜.
public struct MilestoneDay: Hashable, Sendable {
  public let milestone: Milestone
  public let day: CalendarDay

  public init(milestone: Milestone, day: CalendarDay) {
    self.milestone = milestone
    self.day = day
  }
}

public extension DDayCalculator {
  /// `today` 를 포함해 그 뒤의 100일 단위 기념일, 가까운 순 최대 `limit` 개.
  /// 시작일 당일(D+0, 1일째)은 기념일이 아니라 첫 기념일은 늘 100 이다 (시작일이 미래여도).
  /// dDay 방식, 시작일을 구할 수 없음(음력 표 범위 밖·없는 음력 날짜), `limit <= 0` 이면 []. 날짜 표현 범위를 넘으면 그 앞까지.
  static func hundredDayMilestones(
    of schedule: DDaySchedule,
    onOrAfter today: CalendarDay,
    limit: Int
  ) -> [MilestoneDay] {
    // 화면 숫자 n 의 날짜 = 시작일 + n + shift (D+ 는 0, 1일째는 −1)
    let shift: Int
    switch schedule.countingStyle {
    case .dDay: return []
    case .dPlus: shift = 0
    case .dayOne: shift = -1
    }
    guard limit > 0, let start = self.originalDay(of: schedule.date) else { return [] }
    // 일수 차이는 표현 범위(약 365만 일) 안이라 넘치지 않는다.
    let elapsed = today.days(from: start) - shift
    var multiple = elapsed <= 100 ? 1 : (elapsed + 99) / 100
    var result: [MilestoneDay] = []
    while result.count < limit {
      let (number, overflow) = multiple.multipliedReportingOverflow(by: 100)
      guard !overflow, let day = start.adding(days: number + shift) else { break }
      result.append(MilestoneDay(milestone: .hundredDays(number), day: day))
      multiple += 1
    }
    return result
  }

  /// `today` 를 포함해 그 뒤의 N주년(N ≥ 1), 가까운 순 최대 `limit` 개. 날짜는 `occurrence(of:inYear: 시작 연도 + N)`
  /// (음력이면 음력 연도, 2/29·윤달은 매년 반복 규칙). 음력 표 범위를 넘으면 그 앞까지.
  /// dDay 방식, 시작일을 구할 수 없음, `limit <= 0` 이면 [].
  static func anniversaries(
    of schedule: DDaySchedule,
    onOrAfter today: CalendarDay,
    limit: Int
  ) -> [MilestoneDay] {
    // 시작일을 먼저 확인한다: 구할 수 있으면 연도가 1~9999(음력 1900~2050)라 아래 연도 산술이 넘치지 않는다.
    guard schedule.countingStyle != .dDay, limit > 0, self.originalDay(of: schedule.date) != nil else { return [] }
    let startYear = switch schedule.date {
    case let .solar(day): day.year
    case let .lunar(lunar): lunar.year
    }
    // 음력 연도 Y 의 날짜는 양력 Y 년이나 Y+1 년에 오므로 한 해 앞부터 본다.
    var years = max(1, today.year - startYear - 1)
    var result: [MilestoneDay] = []
    while result.count < limit, startYear + years <= CalendarDay.maximumYear {
      guard let day = self.occurrence(of: schedule.date, inYear: startYear + years) else { break }
      if day >= today {
        result.append(MilestoneDay(milestone: .years(years), day: day))
      }
      years += 1
    }
    return result
  }
}
