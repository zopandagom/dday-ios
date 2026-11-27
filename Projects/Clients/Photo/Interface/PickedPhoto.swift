import Foundation

/// 사용자가 고른 사진 하나. 원본 데이터는 `loadData()` 를 부를 때 읽는다 (선택기 로드·iCloud 내려받기 포함).
/// 읽지 못하면(취소 포함) `.readFailed` 를 던진다.
public struct PickedPhoto: Sendable {
  public let loadData: @Sendable () async throws(PhotoError) -> Data

  public init(loadData: @escaping @Sendable () async throws(PhotoError) -> Data) {
    self.loadData = loadData
  }
}
