/// 목록 정렬 그룹. 선언 순서가 위 → 아래.
public enum DDayListGroup: Int, Hashable, Sendable, Comparable {
  /// 다가오는: 남은 날이 0 이상인 dDay, 시작 전 dPlus·dayOne
  case upcoming
  /// 세는 중: 시작일이 오늘이거나 지난 dPlus·dayOne
  case counting
  /// 지난: 반복 없는 dDay 중 날짜가 지난 것
  case passed
  /// 날짜 계산 불가 (음력 표 범위 밖, 그해 없는 음력 날짜)
  case unavailable

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// 카드의 카운트 분류. 문구("D-3", "11일째")는 Feature 가 String Catalog 로 만든다.
public enum DDayCountLabel: Hashable, Sendable {
  /// n ≥ 1 일 남음 → "D-n"
  case daysLeft(Int)
  /// dDay 당일, dPlus 시작 당일 → "D-DAY"
  case dDay
  /// n ≥ 1 일 지남 → "D+n"
  case daysPassed(Int)
  /// 시작일을 1일로 센 n ≥ 1 번째 날 → "n일째" / "Day n"
  case dayNumber(Int)
  /// 날짜 계산 불가
  case unavailable
}

/// 디데이 하나의 오늘 기준 상태 (목록 그룹·카운트·날짜).
/// 불변식: `date == nil` ⇔ `group == .unavailable` ⇔ `label == .unavailable`.
/// 날짜·일수는 `DDayCalculator` 로만 구하므로 `label` 에서 되돌린 값은 `DDayCalculator.dayCount` 와 같다.
public struct DDayStatus: Hashable, Sendable {
  public let group: DDayListGroup
  public let label: DDayCountLabel
  /// 카운트가 가리키는 날짜를 디데이와 같은 달력으로: 매년 반복 dDay 는 다음 날짜, 그 밖은 처음 날짜.
  /// 음력 디데이면 그 양력 날짜를 `KoreanLunarCalendar.lunarDate(from:)` 로 바꾼 `.lunar` (윤달·평달 대체·30→29일이 반영된 실제 음력).
  /// 계산 불가면 nil.
  public let date: DDayDate?
  /// 같은 그룹 안 정렬 키 (작을수록 위).
  let sortKey: Int

  /// 분류 규칙 (`d` = 기준 날짜 − 오늘):
  /// - 기준 날짜: 매년 반복 dDay 는 오늘 이후 다음 날짜, 그 밖(반복 없는 dDay, 모든 dPlus·dayOne)은 처음 날짜.
  ///   dPlus·dayOne 은 반복 규칙을 보지 않는다 (`DDayCalculator.dayCount` 와 같다).
  /// - dDay: d ≥ 0 이면 다가오는(키 d), d < 0 이면 지난(키 −d, 최근 지난 순).
  /// - dPlus·dayOne: d > 0 이면 다가오는(키 d), d ≤ 0 이면 세는 중(키 −d, 시작 당일이 맨 위).
  /// - 기준 날짜를 구할 수 없으면 계산 불가.
  public init(schedule: DDaySchedule, today: CalendarDay) {
    let reference: CalendarDay? = switch (schedule.countingStyle, schedule.repeatRule) {
    case (.dDay, .yearly): DDayCalculator.nextOccurrence(of: schedule, onOrAfter: today)
    default: DDayCalculator.originalDay(of: schedule.date)
    }
    guard let reference, let date = Self.date(of: reference, like: schedule.date) else {
      self.init(group: .unavailable, label: .unavailable, date: nil, sortKey: 0)
      return
    }
    let days = reference.days(from: today)
    let (group, label) = Self.classify(schedule.countingStyle, days: days)
    // 모든 경우에 정렬 키는 |d|: 다가오는은 남은 날 적은 순, 세는 중·지난은 최근 순.
    self.init(group: group, label: label, date: date, sortKey: abs(days))
  }

  init(group: DDayListGroup, label: DDayCountLabel, date: DDayDate?, sortKey: Int) {
    self.group = group
    self.label = label
    self.date = date
    self.sortKey = sortKey
  }

  /// 계산할 수 있는 디데이의 그룹과 카운트. `days` = 기준 날짜 − 오늘.
  private static func classify(_ style: CountingStyle, days: Int) -> (DDayListGroup, DDayCountLabel) {
    if days > 0 {
      return (.upcoming, .daysLeft(days))
    }
    switch style {
    case .dDay: return days == 0 ? (.upcoming, .dDay) : (.passed, .daysPassed(-days))
    case .dPlus: return days == 0 ? (.counting, .dDay) : (.counting, .daysPassed(-days))
    case .dayOne: return (.counting, .dayNumber(-days + 1))
    }
  }

  /// 기준 양력 날짜를 디데이와 같은 달력으로. 음력 역변환은 표에서 구한 날짜라 정상 데이터에서 실패하지 않지만,
  /// 실패하면 nil 을 돌려 상태 전체를 계산 불가로 둔다 (카운트만 있고 날짜가 없는 반쪽 상태를 만들지 않는다).
  private static func date(of reference: CalendarDay, like original: DDayDate) -> DDayDate? {
    switch original {
    case .solar: .solar(reference)
    case .lunar: KoreanLunarCalendar.lunarDate(from: reference).map(DDayDate.lunar)
    }
  }
}
