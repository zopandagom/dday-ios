import Testing
@testable import Core

struct DDayStatusTests {
  /// 상태를 계산할 입력 하나.
  struct Sample: Sendable {
    let schedule: DDaySchedule
    let today: CalendarDay

    var status: DDayStatus {
      DDayStatus(schedule: self.schedule, today: self.today)
    }
  }

  private static let today = CalendarDay(unchecked: 2026, 11, 26)

  private static func solar(_ year: Int, _ month: Int, _ day: Int) -> DDayDate {
    .solar(CalendarDay(unchecked: year, month, day))
  }

  private static func sample(
    _ date: DDayDate,
    _ repeatRule: RepeatRule = .none,
    _ countingStyle: CountingStyle = .dDay,
    today: CalendarDay = Self.today
  ) -> Sample {
    Sample(schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle), today: today)
  }

  // MARK: - 1. 반복 없는 dDay

  @Test("반복 없는 dDay: 남으면 다가오는, 당일은 D-DAY, 지나면 지난 그룹(최근 지난 순)")
  func dDayOnce() {
    #expect(Self.dDayLeft3.status == DDayStatus(
      group: .upcoming,
      label: .daysLeft(3),
      date: Self.solar(2026, 11, 29),
      sortKey: 3
    ))
    #expect(Self.dDayToday.status == DDayStatus(
      group: .upcoming,
      label: .dDay,
      date: Self.solar(2026, 11, 26),
      sortKey: 0
    ))
    #expect(
      Self.dDayPassed10.status
        == DDayStatus(group: .passed, label: .daysPassed(10), date: Self.solar(2026, 11, 16), sortKey: 10)
    )
  }

  // MARK: - 2. 매년 양력 dDay

  @Test("매년 양력 dDay: 올해 지났으면 내년 날짜, 당일이면 D-DAY, 처음 날짜가 미래 해면 그 날짜")
  func solarYearly() {
    let passedThisYear = Self.yearlyPassedThisYear.status
    #expect(passedThisYear.group == .upcoming)
    #expect(passedThisYear.label == .daysLeft(95))
    #expect(passedThisYear.date == Self.solar(2027, 3, 1))

    #expect(Self.yearlyToday.status == DDayStatus(
      group: .upcoming,
      label: .dDay,
      date: Self.solar(2026, 11, 26),
      sortKey: 0
    ))

    let future = Self.yearlyFutureYear.status
    #expect(future.group == .upcoming)
    #expect(future.date == Self.solar(2028, 3, 1))
    #expect(future.label == .daysLeft(CalendarDay(unchecked: 2028, 3, 1).days(from: Self.today)))
  }

  // MARK: - 3. 윤년

  @Test("윤년: 매년 2/29 는 평년에 2/28, 윤년에 2/29. dPlus 는 2/29 를 하루로 센다")
  func leapYear() {
    #expect(Self.leapDayCommonYear.status.date == Self.solar(2027, 2, 28))
    #expect(Self.leapDayLeapYear.status.date == Self.solar(2028, 2, 29))
    #expect(Self.dPlusOverLeapDay.status.group == .counting)
    #expect(Self.dPlusOverLeapDay.status.label == .daysPassed(2))
  }

  // MARK: - 4. 연도 넘김

  @Test("연도 넘김: 해가 바뀌어도 남은 날·N일째가 이어진다")
  func acrossYear() {
    #expect(Self.dDayAcrossYear.status.label == .daysLeft(3))
    #expect(Self.dayOneAcrossYear.status.label == .dayNumber(2))
    #expect(Self.dayOneAcrossYear.status.group == .counting)
  }

  // MARK: - 5. dPlus

  @Test("dPlus: 시작 전은 다가오는, 시작 당일은 세는 중 맨 위(D-DAY), 그 뒤는 최근 시작 순")
  func dPlus() {
    #expect(
      Self.dPlusBefore3.status == DDayStatus(
        group: .upcoming,
        label: .daysLeft(3),
        date: Self.solar(2026, 11, 29),
        sortKey: 3
      )
    )
    #expect(
      Self.dPlusStartDay.status == DDayStatus(
        group: .counting,
        label: .dDay,
        date: Self.solar(2026, 11, 26),
        sortKey: 0
      )
    )
    // dPlus 는 반복 규칙을 보지 않는다 (매년이어도 처음 날짜 기준).
    #expect(
      Self.dPlusAfter10.status
        == DDayStatus(group: .counting, label: .daysPassed(10), date: Self.solar(2026, 11, 16), sortKey: 10)
    )
  }

  // MARK: - 6. dayOne

  @Test("dayOne: 시작 전은 다가오는, 시작 당일은 1일째(세는 중 맨 위), 10일 뒤는 11일째")
  func dayOne() {
    // dayOne 은 반복 규칙을 보지 않는다 (매년이어도 처음 날짜 기준).
    #expect(
      Self.dayOneBefore3.status == DDayStatus(
        group: .upcoming,
        label: .daysLeft(3),
        date: Self.solar(2026, 11, 29),
        sortKey: 3
      )
    )
    #expect(
      Self.dayOneStartDay.status
        == DDayStatus(group: .counting, label: .dayNumber(1), date: Self.solar(2026, 11, 26), sortKey: 0)
    )
    #expect(
      Self.dayOneAfter10.status
        == DDayStatus(group: .counting, label: .dayNumber(11), date: Self.solar(2026, 11, 16), sortKey: 10)
    )
  }

  // MARK: - 7. 음력

  @Test("음력: 날짜는 카운트가 가리키는 실제 음력 (윤달 없는 해는 평달, 30일 없는 달은 29일)")
  func lunar() {
    let chuseok2027 = DDayDate.lunar(LunarDate(year: 2027, month: 8, day: 15))
    // 음력 2027-08-15 = 양력 2027-09-15
    #expect(Self.lunarOnce.status == DDayStatus(
      group: .upcoming,
      label: .daysLeft(293),
      date: chuseok2027,
      sortKey: 293
    ))
    #expect(
      Self.lunarChuseokYearly.status == DDayStatus(
        group: .upcoming,
        label: .daysLeft(293),
        date: chuseok2027,
        sortKey: 293
      )
    )
    #expect(Self.lunarLeapYearlyInLeapYear.status.date == .lunar(LunarDate(
      year: 2025,
      month: 6,
      day: 1,
      isLeapMonth: true
    )))
    // 2026 년에는 윤6월이 없어 평달 6/1 (양력 2026-07-14)
    #expect(
      Self.lunarLeapYearlyNoLeap.status
        == DDayStatus(
          group: .upcoming,
          label: .daysLeft(194),
          date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: false)),
          sortKey: 194
        )
    )
    // 2027 년 음력 1월은 29일까지라 1/29 (양력 2027-03-07)
    #expect(Self.lunarMissingThirtieth.status.date == .lunar(LunarDate(year: 2027, month: 1, day: 29)))
    #expect(Self.lunarMissingThirtieth.status.label == .daysLeft(6))
    // 음력 2026-10-07 = 양력 2026-11-15
    #expect(Self.lunarDPlus.status.label == .daysPassed(11))
    #expect(Self.lunarDPlus.status.date == .lunar(LunarDate(year: 2026, month: 10, day: 7)))
  }

  // MARK: - 8. 계산 불가

  @Test("계산 불가: 그해 없는 윤달·표 범위 밖 음력·표 끝 뒤의 다음 날짜는 날짜 없이 맨 아래 그룹")
  func unavailableStatus() {
    for sample in Self.unavailable {
      #expect(sample.status == DDayStatus(group: .unavailable, label: .unavailable, date: nil, sortKey: 0))
    }
  }

  @Test("불변식: date 가 nil ⇔ group 이 계산 불가 ⇔ label 이 계산 불가")
  func invariant() {
    for sample in Self.computable + Self.unavailable {
      let status = sample.status
      #expect((status.date == nil) == (status.group == .unavailable))
      #expect((status.group == .unavailable) == (status.label == .unavailable))
    }
    for sample in Self.computable {
      #expect(sample.status.date != nil)
    }
  }

  // MARK: - 9. dayCount 와 일치

  @Test("label 에서 되돌린 일수가 DDayCalculator.dayCount 와 같다")
  func matchesDayCount() {
    for sample in Self.computable + Self.unavailable {
      let expected = DDayCalculator.dayCount(of: sample.schedule, today: sample.today)
      let label = sample.status.label
      guard let restored = Self.dayCount(from: label, style: sample.schedule.countingStyle) else {
        Issue.record("세는 방식 \(sample.schedule.countingStyle) 에 나올 수 없는 label \(label)")
        continue
      }
      #expect(restored == expected, "\(sample.schedule) @ \(sample.today)")
    }
  }

  /// label 을 세는 방식별 `dayCount` 값으로 되돌린다. 바깥 Optional 이 nil 이면 나올 수 없는 조합.
  private static func dayCount(from label: DDayCountLabel, style: CountingStyle) -> Int?? {
    switch (style, label) {
    case (_, .unavailable): .some(nil)
    case let (.dDay, .daysLeft(days)): days
    case (.dDay, .dDay): 0
    case let (.dDay, .daysPassed(days)): -days
    case let (.dPlus, .daysLeft(days)): -days
    case (.dPlus, .dDay): 0
    case let (.dPlus, .daysPassed(days)): days
    case let (.dayOne, .daysLeft(days)): 1 - days
    case let (.dayOne, .dayNumber(days)): days
    default: nil
    }
  }
}

// MARK: - 샘플 (테스트 1~8, 8·9 는 전체 목록을 다시 쓴다)

extension DDayStatusTests {
  // 1. 반복 없는 dDay
  private static let dDayLeft3 = sample(solar(2026, 11, 29))
  private static let dDayToday = sample(solar(2026, 11, 26))
  private static let dDayPassed10 = sample(solar(2026, 11, 16))
  // 2. 매년 양력 dDay
  private static let yearlyPassedThisYear = sample(solar(2020, 3, 1), .yearly)
  private static let yearlyToday = sample(solar(2020, 11, 26), .yearly)
  private static let yearlyFutureYear = sample(solar(2028, 3, 1), .yearly)
  // 3. 윤년
  private static let leapDayCommonYear = sample(solar(2024, 2, 29), .yearly)
  private static let leapDayLeapYear = sample(solar(2024, 2, 29), .yearly, today: CalendarDay(unchecked: 2028, 1, 1))
  private static let dPlusOverLeapDay = sample(
    solar(2028, 2, 28),
    .none,
    .dPlus,
    today: CalendarDay(unchecked: 2028, 3, 1)
  )
  // 4. 연도 넘김
  private static let dDayAcrossYear = sample(solar(2027, 1, 2), today: CalendarDay(unchecked: 2026, 12, 30))
  private static let dayOneAcrossYear = sample(
    solar(2026, 12, 31),
    .none,
    .dayOne,
    today: CalendarDay(unchecked: 2027, 1, 1)
  )
  // 5. dPlus
  private static let dPlusBefore3 = sample(solar(2026, 11, 29), .none, .dPlus)
  private static let dPlusStartDay = sample(solar(2026, 11, 26), .none, .dPlus)
  private static let dPlusAfter10 = sample(solar(2026, 11, 16), .yearly, .dPlus)
  // 6. dayOne
  private static let dayOneBefore3 = sample(solar(2026, 11, 29), .yearly, .dayOne)
  private static let dayOneStartDay = sample(solar(2026, 11, 26), .none, .dayOne)
  private static let dayOneAfter10 = sample(solar(2026, 11, 16), .none, .dayOne)
  // 7. 음력
  private static let lunarOnce = sample(.lunar(LunarDate(year: 2027, month: 8, day: 15)))
  private static let lunarChuseokYearly = sample(.lunar(LunarDate(year: 2000, month: 8, day: 15)), .yearly)
  private static let lunarLeapYearlyInLeapYear = sample(
    .lunar(LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)),
    .yearly,
    today: CalendarDay(unchecked: 2025, 1, 1)
  )
  private static let lunarLeapYearlyNoLeap = sample(
    .lunar(LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true)),
    .yearly,
    today: CalendarDay(unchecked: 2026, 1, 1)
  )
  private static let lunarMissingThirtieth = sample(
    .lunar(LunarDate(year: 2000, month: 1, day: 30)),
    .yearly,
    today: CalendarDay(unchecked: 2027, 3, 1)
  )
  private static let lunarDPlus = sample(.lunar(LunarDate(year: 2026, month: 10, day: 7)), .none, .dPlus)
  // 8. 계산 불가
  private static let missingLeapMonth = sample(.lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)))
  private static let beyondTableYear = sample(.lunar(LunarDate(year: 2051, month: 1, day: 1)))
  private static let yearlyBeyondTableEnd = sample(
    .lunar(LunarDate(year: 2000, month: 1, day: 1)),
    .yearly,
    today: CalendarDay(unchecked: 2050, 12, 31)
  )
  private static let dPlusMissingStart = sample(
    .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)),
    .none,
    .dPlus
  )
  private static let dayOneMissingStart = sample(.lunar(LunarDate(year: 2051, month: 1, day: 1)), .yearly, .dayOne)

  private static let computable: [Sample] = [
    dDayLeft3, dDayToday, dDayPassed10,
    yearlyPassedThisYear, yearlyToday, yearlyFutureYear,
    leapDayCommonYear, leapDayLeapYear, dPlusOverLeapDay,
    dDayAcrossYear, dayOneAcrossYear,
    dPlusBefore3, dPlusStartDay, dPlusAfter10,
    dayOneBefore3, dayOneStartDay, dayOneAfter10,
    lunarOnce, lunarChuseokYearly, lunarLeapYearlyInLeapYear, lunarLeapYearlyNoLeap, lunarMissingThirtieth, lunarDPlus,
  ]

  private static let unavailable: [Sample] = [
    missingLeapMonth, beyondTableYear, yearlyBeyondTableEnd, dPlusMissingStart, dayOneMissingStart,
  ]
}
