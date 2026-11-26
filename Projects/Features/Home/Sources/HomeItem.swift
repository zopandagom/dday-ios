import Core
import DDayStoreInterface
import Foundation

/// 목록의 카드 하나: 저장된 디데이와 오늘 기준 상태.
public struct HomeItem: Identifiable, Equatable, Sendable {
  public let dDay: DDay
  public let status: DDayStatus
  public var id: UUID { self.dDay.id }

  /// Example·Preview 가 카드 하나를 만들 때 쓴다.
  public init(dDay: DDay, status: DDayStatus) {
    self.dDay = dDay
    self.status = status
  }

  /// 정렬 결과에서 만든다.
  init(entry: DDayListEntry<DDay>) {
    self.init(dDay: entry.item, status: entry.status)
  }
}
