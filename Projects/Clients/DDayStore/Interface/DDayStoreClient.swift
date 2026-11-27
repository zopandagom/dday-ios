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
/// 폴더 id 정규화(에러는 아니다): `add`·`update` 는 draft 가 행이 없는 폴더를 가리키면 nil(미분류)로 저장·반환한다.
/// `fetchAll` 은 저장된 행이 없거나 읽을 수 없는 폴더를 가리키면 nil 로 돌려준다. 읽을 수 없는 폴더 행은 쓰기가 만들 수
/// 없는 값이라 정상 흐름에서 둘은 같다.
/// 폴더 쓰기(`addFolder`·`updateFolder`·`moveFolders`·`deleteFolder`)는 각각 한 번의 save 라 실패하면 그 호출의 변경이
/// 하나도 남지 않는다.
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

  /// 폴더를 맨 뒤에 추가하고 저장된 값을 돌려준다 (새 id, 기본 폴더 키 없음).
  /// 이름이 규칙에 맞지 않거나 `.system` 이면 `.invalidFolderName`, 같은 id 가 이미 있으면 `.alreadyExists`,
  /// 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func addFolder(_ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder

  /// 폴더의 이름·색·아이콘을 바꾼다. 순서·생성 시각·기본 폴더 키는 그대로다.
  /// 이름: `.custom` 은 정리해 저장하고 그때부터 그 이름으로 보인다 (기본 폴더도). `.system(key)` 는 그 행의 기본 폴더 키가
  /// `key` 일 때만 받아 기본 이름(앱 언어)으로 보인다.
  /// 그 id 가 없으면 `.notFound`, 이름이 맞지 않으면 `.invalidFolderName`, 저장소를 열거나 읽지 못하면 `.loadFailed`,
  /// 저장하지 못하면 `.saveFailed`.
  func updateFolder(id: UUID, _ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder

  /// 폴더 순서를 `orderedIDs` 순서로 바꾸고 그 순서의 폴더 목록을 돌려준다 (`fetchFolders` 와 같은 값).
  /// `orderedIDs` 는 지금 읽을 수 있는 폴더 id 전체여야 한다: 빠지거나 남거나 겹치면 `.notFound` 이고 아무것도 바꾸지 않는다.
  /// 읽을 수 없는 폴더 행의 순서는 건드리지 않는다. 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func moveFolders(_ orderedIDs: [UUID]) async throws(DDayStoreError) -> [DDayFolder]

  /// 폴더를 지우고, 안의 디데이를 `dDays` 대로 미분류로 옮기거나 사진과 함께 지운다 (폴더 삭제와 한 번의 save).
  /// 함께 지운 디데이 id 를 `fetchAll` 순서로 돌려준다 (`.moveToUnfiled` 면 늘 빈 배열).
  /// 읽을 수 없는 디데이 행은 지우지 않고 미분류로 옮긴다 (두 방식 모두). 그 id 가 없으면 `.notFound`,
  /// 저장소를 열거나 읽지 못하면 `.loadFailed`, 저장하지 못하면 `.saveFailed`.
  func deleteFolder(id: UUID, dDays: FolderDeletion) async throws(DDayStoreError) -> [UUID]
}
