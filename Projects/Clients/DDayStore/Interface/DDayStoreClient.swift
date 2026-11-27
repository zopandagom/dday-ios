import Foundation

/// 디데이 저장소. id·생성/수정 시각·사진 id 는 저장소가 정한다.
/// `.loadFailed` 는 일시적일 수 있다 (예: 기기 첫 잠금 해제 전). 같은 저장소로 다시 부르면 성공할 수 있다.
///
/// 사진: 목록(`fetchAll`)은 썸네일(`DDay.photo`)만 돌려주고, 압축본은 `fetchPhoto(id:)` 로만 읽는다.
/// 추가·수정의 `draft.photo` 는 `.keep`(그대로)·`.replace`(새 사진 id 로 바꿈)·`.remove`(지움)이고, 추가에서
/// `.keep`·`.remove` 는 사진 없음이다. 사진 바꾸기·지우기·디데이 삭제는 썸네일과 압축본을 한 번에 저장해
/// 실패하면 둘 다 그대로 남는다.
///
/// 폴더: 저장소를 처음 열 때(어느 메서드든 첫 호출) 기본 폴더가 아직 만들어진 적 없으면 `DefaultFolder` 순서로 네 개를
/// 만들고 "만들었음" 표시를 같은 save 로 남긴다. 표시가 있으면 폴더가 몇 개든(0개여도) 다시 만들지 않는다. 이 생성에
/// 실패하면 그 호출이 `.loadFailed` 이고 다음 호출이 다시 연다 (열기 실패와 같다).
/// `fetchAll`·`add`·`update` 가 돌려주는 `DDay.folderID` 는 있는 폴더 id 거나 nil 이다: draft 나 저장된 행이 없는(또는
/// 읽을 수 없는) 폴더를 가리키면 nil(미분류)로 저장·반환한다. 에러는 아니다.
public protocol DDayStoreClient: Sendable {
  /// 저장된 디데이 전부. 생성 시각 오름차순(같으면 id 문자열 오름차순). 읽을 수 없는 행은 빼고 돌려준다.
  /// 압축본은 읽지 않는다. 저장소를 열거나 읽지 못하면 `.loadFailed`.
  func fetchAll() async throws(DDayStoreError) -> [DDay]

  /// 새 id·생성 시각으로 추가하고 저장된 값을 돌려준다. 생성 시각과 수정 시각은 같다.
  /// 같은 id 가 이미 있으면 `.alreadyExists`, 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay

  /// 내용을 `draft` 로 바꾼다. 생성 시각은 유지하고 수정 시각을 갱신한다. 돌려준 값의 `photo` 는 저장 뒤 상태다.
  /// 그 id 가 없으면 `.notFound`, 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay

  /// 그 id 의 디데이를 사진(썸네일·압축본)과 함께 지운다. 없으면 `.notFound`, 저장소를 열거나 읽지 못하면
  /// `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func delete(id: UUID) async throws(DDayStoreError)

  /// 그 디데이의 압축본 JPEG. 사진이 없거나 압축본 행이 없거나 사진 id 가 짝이 맞지 않으면 nil.
  /// 그 id 의 디데이가 없으면 `.notFound`, 저장소를 열거나 읽지 못하면 `.loadFailed`.
  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data?

  /// 폴더 전부. 순서대로, 순서가 같으면 생성 시각·id 문자열 오름차순. 읽을 수 없는 행은 빼고 돌려준다.
  /// 기본 폴더는 저장소를 처음 열 때 한 번 만든다 (위). 저장소를 열거나 읽지 못하면 `.loadFailed`.
  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder]
}
