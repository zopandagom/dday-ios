/// 정렬된 항목과 그 오늘 기준 상태.
public struct DDayListEntry<Item> {
  public let item: Item
  public let status: DDayStatus
}

extension DDayListEntry: Sendable where Item: Sendable {}
extension DDayListEntry: Equatable where Item: Equatable {}

/// 디데이 목록 정렬.
public enum DDayListOrder {
  /// 그룹(위→아래: 다가오는 → 세는 중 → 지난 → 계산 불가) → 그룹 안 `sortKey` 오름차순 → 입력 순서로 정렬한다.
  /// 입력 순서 유지는 `enumerated()` 의 offset 을 마지막 비교 키로 써서 보장한다 (정렬 알고리즘 안정성에 기대지 않는다).
  public static func entries<Item>(
    _ items: [Item],
    today: CalendarDay,
    schedule: (Item) -> DDaySchedule
  ) -> [DDayListEntry<Item>] {
    let keyed = items.enumerated().map { offset, item in
      (offset: offset, entry: DDayListEntry(item: item, status: DDayStatus(schedule: schedule(item), today: today)))
    }
    return keyed
      .sorted { lhs, rhs in
        (lhs.entry.status.group.rawValue, lhs.entry.status.sortKey, lhs.offset)
          < (rhs.entry.status.group.rawValue, rhs.entry.status.sortKey, rhs.offset)
      }
      .map(\.entry)
  }
}
