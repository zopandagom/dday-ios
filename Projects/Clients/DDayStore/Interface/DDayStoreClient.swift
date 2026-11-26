import Foundation

/// 디데이 저장소. id·생성/수정 시각은 저장소가 정한다.
/// `.loadFailed` 는 일시적일 수 있다 (예: 기기 첫 잠금 해제 전). 같은 저장소로 다시 부르면 성공할 수 있다.
public protocol DDayStoreClient: Sendable {
  /// 저장된 디데이 전부. 생성 시각 오름차순(같으면 id 문자열 오름차순). 읽을 수 없는 행은 빼고 돌려준다.
  /// 저장소를 열거나 읽지 못하면 `.loadFailed`.
  func fetchAll() async throws(DDayStoreError) -> [DDay]

  /// 새 id·생성 시각으로 추가하고 저장된 값을 돌려준다. 생성 시각과 수정 시각은 같다.
  /// 같은 id 가 이미 있으면 `.alreadyExists`, 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay

  /// 내용을 `draft` 로 바꾼다. 생성 시각은 유지하고 수정 시각을 갱신한다.
  /// 그 id 가 없으면 `.notFound`, 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay

  /// 그 id 의 디데이를 지운다. 없으면 `.notFound`, 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func delete(id: UUID) async throws(DDayStoreError)
}
