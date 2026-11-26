import Testing
@testable import Core

struct DDayListOrderTests {
  /// 정렬 입력 항목. 이름으로 결과 순서를 비교한다.
  struct Item: Equatable, Sendable {
    let name: String
    let schedule: DDaySchedule
  }

  private let today = CalendarDay(unchecked: 2026, 11, 26)

  /// 오늘에서 `offset` 일 뒤(음수면 앞)의 양력 날짜.
  private func day(_ offset: Int) -> DDayDate {
    .solar(CalendarDay(julianDayNumber: self.today.julianDayNumber + offset) ?? self.today)
  }

  private func item(_ name: String, _ offset: Int, _ countingStyle: CountingStyle = .dDay) -> Item {
    Item(name: name, schedule: DDaySchedule(date: self.day(offset), countingStyle: countingStyle))
  }

  /// 그해 없는 윤달이라 날짜 계산 불가.
  private func unavailableItem(_ name: String) -> Item {
    Item(name: name, schedule: DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true))))
  }

  private func names(_ items: [Item]) -> [String] {
    DDayListOrder.entries(items, today: self.today, schedule: \.schedule).map(\.item.name)
  }

  // MARK: - 10. 그룹·그룹 안 순서

  @Test("다가오는(당일→남은 날 적은 순) → 세는 중(시작 당일→최근 시작 순) → 지난(최근 순) → 계산 불가")
  func groupsAndKeys() {
    let input = [
      self.item("지난20", -20),
      self.unavailableItem("불가1"),
      self.item("세는중10", -10, .dPlus),
      self.item("다가옴30", 30),
      self.item("지난1", -1),
      self.item("세는중시작", 0, .dPlus),
      self.item("다가옴3", 3),
      self.unavailableItem("불가2"),
      self.item("세는중2", -2, .dayOne),
      self.item("다가옴당일", 0),
      self.item("시작전5", 5, .dPlus),
    ]
    #expect(
      self.names(input) == [
        "다가옴당일", "다가옴3", "시작전5", "다가옴30",
        "세는중시작", "세는중2", "세는중10",
        "지난1", "지난20",
        "불가1", "불가2",
      ]
    )
    let groups = DDayListOrder.entries(input, today: self.today, schedule: \.schedule).map(\.status.group)
    #expect(groups == groups.sorted())
  }

  // MARK: - 11. 시작 당일

  @Test("시작 당일 dPlus·dayOne 은 모든 다가오는 항목 아래, 세는 중 맨 위")
  func startDayBelowUpcoming() {
    let input = [
      self.item("세는중1", -1, .dPlus),
      self.item("dPlus시작", 0, .dPlus),
      self.item("다가옴300", 300),
      self.item("dayOne시작", 0, .dayOne),
      self.item("다가옴1", 1),
    ]
    #expect(self.names(input) == ["다가옴1", "다가옴300", "dPlus시작", "dayOne시작", "세는중1"])
  }

  // MARK: - 12. 입력 순서 유지

  @Test("같은 그룹·같은 키와 계산 불가 항목은 입력 순서를 지키고, 입력을 뒤집으면 그 순서도 뒤집힌다")
  func stable() {
    let input = [
      self.unavailableItem("불가A"),
      self.item("같은날A", 3),
      self.item("다가옴1", 1),
      self.unavailableItem("불가B"),
      self.item("같은날B", 3),
    ]
    #expect(self.names(input) == ["다가옴1", "같은날A", "같은날B", "불가A", "불가B"])
    #expect(self.names(input.reversed()) == ["다가옴1", "같은날B", "같은날A", "불가B", "불가A"])
  }

  // MARK: - 13. 빈 입력·제네릭

  @Test("빈 입력은 빈 결과")
  func empty() {
    #expect(DDayListOrder.entries([Item](), today: self.today, schedule: \.schedule).isEmpty)
  }

  @Test("Item 이 임의 타입이어도 schedule 클로저로 정렬하고, status 는 DDayStatus(schedule:today:) 와 같다")
  func genericItem() {
    let schedules: [String: DDaySchedule] = [
      "지난": DDaySchedule(date: self.day(-5)),
      "다가옴": DDaySchedule(date: self.day(7)),
      "세는중": DDaySchedule(date: self.day(-3), countingStyle: .dayOne),
    ]
    let fallback = DDaySchedule(date: self.day(0))
    let entries = DDayListOrder.entries(["지난", "다가옴", "세는중"], today: self.today) { schedules[$0] ?? fallback }
    #expect(entries.map(\.item) == ["다가옴", "세는중", "지난"])
    for entry in entries {
      #expect(entry.status == DDayStatus(schedule: schedules[entry.item] ?? fallback, today: self.today))
    }
  }
}
