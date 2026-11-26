/// 디데이의 다음 날짜와 남은·지난 날 계산. 모든 계산은 `CalendarDay`(JDN) 로 해서 시간대 영향이 없다.
public enum DDayCalculator {
  /// 처음 정한 날짜의 양력 날짜. 음력이 그해에 없는 날짜이거나 표 범위 밖이면 `nil`.
  public static func originalDay(of date: DDayDate) -> CalendarDay? {
    switch date {
    case let .solar(day): day
    case let .lunar(lunar): KoreanLunarCalendar.solarDay(from: lunar)
    }
  }

  /// 매년 반복할 때 `year` 년(음력이면 음력 연도)에 오는 날짜.
  /// - 양력 2/29 는 평년에 2/28.
  /// - 음력 윤달은 그해 그 윤달이 없으면 같은 달 평달, 그 달이 29일까지면 30일 → 29일.
  /// 표 범위 밖이면 `nil`.
  public static func occurrence(of date: DDayDate, inYear year: Int) -> CalendarDay? {
    switch date {
    case let .solar(day):
      guard year >= 1 else { return nil }
      let lastDay = CalendarDay.numberOfDays(year: year, month: day.month)
      return CalendarDay(year: year, month: day.month, day: min(day.day, lastDay))
    case let .lunar(lunar):
      let isLeap = lunar.isLeapMonth && KoreanLunarCalendar.leapMonth(in: year) == lunar.month
      guard let lastDay = KoreanLunarCalendar.numberOfDays(year: year, month: lunar.month, isLeapMonth: isLeap)
      else {
        return nil
      }
      return KoreanLunarCalendar.solarDay(
        from: LunarDate(year: year, month: lunar.month, day: min(lunar.day, lastDay), isLeapMonth: isLeap)
      )
    }
  }

  /// `today` 를 포함해 그 뒤에 오는 날짜를 가까운 순으로 최대 `limit` 개.
  /// 반복 없음이면 처음 날짜 하나(지났으면 빈 목록), 매년이면 처음 날짜의 해부터 센다.
  /// 음력 표 범위를 넘으면 그 앞까지만 돌려준다.
  public static func occurrences(
    of schedule: DDaySchedule,
    onOrAfter today: CalendarDay,
    limit: Int
  ) -> [CalendarDay] {
    guard limit > 0 else { return [] }
    switch schedule.repeatRule {
    case .none:
      guard let day = self.originalDay(of: schedule.date), day >= today else { return [] }
      return [day]
    case .yearly:
      return self.yearlyOccurrences(of: schedule, onOrAfter: today, limit: limit)
    }
  }

  private static func yearlyOccurrences(
    of schedule: DDaySchedule,
    onOrAfter today: CalendarDay,
    limit: Int
  ) -> [CalendarDay] {
    let startYear = switch schedule.date {
    // 양력은 그해 안에 오고, 음력 연도 Y 의 날짜는 양력 Y 년이나 Y+1 년에 온다.
    case let .solar(day): max(day.year, today.year)
    case let .lunar(lunar): max(lunar.year, today.year - 1)
    }
    // 표현할 수 없는 해(예: 잘못 저장된 아주 큰 음력 연도)면 계산하지 않는다.
    guard startYear <= CalendarDay.maximumYear else { return [] }
    var result: [CalendarDay] = []
    var year = startYear
    // 오늘 이후 날짜는 늦어도 startYear + 2 년부터 매년 하나씩 나온다.
    // limit 이 아주 커도 넘치지 않게 CalendarDay 가 표현하는 마지막 해에서 멈춘다.
    let lastYear = min(CalendarDay.maximumYear, startYear + 2 + min(limit, CalendarDay.maximumYear))
    while result.count < limit, year <= lastYear {
      guard let day = self.occurrence(of: schedule.date, inYear: year) else {
        if case .lunar = schedule.date {
          break
        }
        year += 1
        continue
      }
      if day >= today {
        result.append(day)
      }
      year += 1
    }
    return result
  }

  /// `today` 를 포함해 그 뒤에 오는 가장 가까운 날짜. 없으면 `nil`.
  public static func nextOccurrence(of schedule: DDaySchedule, onOrAfter today: CalendarDay) -> CalendarDay? {
    self.occurrences(of: schedule, onOrAfter: today, limit: 1).first
  }

  /// 세는 방식(`CountingStyle`)에 따른 일수. 표시 형식(D-3, D+10, 11일째)은 화면이 정한다.
  /// 목록의 그룹·카운트 분류는 `DDayStatus` 가 같은 규칙으로 만든다.
  /// - `.dDay`: 목표일 - 오늘. 매년 반복이면 목표일은 다음 날짜, 반복 없음이면 처음 날짜(지나면 음수).
  /// - `.dPlus`: 오늘 - 처음 날짜.
  /// - `.dayOne`: 오늘 - 처음 날짜 + 1.
  /// 날짜를 구할 수 없으면(음력 표 범위 밖, 없는 음력 날짜) `nil`.
  public static func dayCount(of schedule: DDaySchedule, today: CalendarDay) -> Int? {
    switch schedule.countingStyle {
    case .dDay:
      let target = switch schedule.repeatRule {
      case .none: self.originalDay(of: schedule.date)
      case .yearly: self.nextOccurrence(of: schedule, onOrAfter: today)
      }
      return target.map { $0.days(from: today) }
    case .dPlus:
      return self.originalDay(of: schedule.date).map { today.days(from: $0) }
    case .dayOne:
      return self.originalDay(of: schedule.date).map { today.days(from: $0) + 1 }
    }
  }
}
