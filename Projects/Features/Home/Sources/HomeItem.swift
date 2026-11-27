import Core
import DDayStoreInterface
import Foundation

/// 목록의 카드 하나: 저장된 디데이, 오늘 기준 상태, 폴더.
public struct HomeItem: Identifiable, Equatable, Sendable {
  public let dDay: DDay
  public let status: DDayStatus
  /// 지금 폴더 목록에서 찾은 디데이의 폴더. 없거나 목록에 없으면 nil (미분류).
  public let folder: DDayFolder?
  public var id: UUID { self.dDay.id }

  /// Example·Preview 가 카드 하나를 만들 때 쓴다.
  public init(dDay: DDay, status: DDayStatus, folder: DDayFolder? = nil) {
    self.dDay = dDay
    self.status = status
    self.folder = folder
  }

  /// 정렬 결과와 그 디데이의 폴더(목록에서 찾은 값)로 만든다.
  init(entry: DDayListEntry<DDay>, folder: DDayFolder?) {
    self.init(dDay: entry.item, status: entry.status, folder: folder)
  }
}
