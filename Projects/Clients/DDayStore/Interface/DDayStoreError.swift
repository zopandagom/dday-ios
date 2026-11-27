/// 디데이 저장소 에러. 프레임워크 에러가 새어 나가지 않도록 연관값을 두지 않는다 (원인 종류는 Impl 로그에만).
public enum DDayStoreError: Error, Equatable, Sendable {
  /// 그 id 의 디데이나 폴더가 없다 (수정·삭제·사진 읽기·폴더 수정·폴더 삭제). 폴더 순서 바꾸기에서는 넘긴 id 목록이
  /// 지금 읽을 수 있는 폴더 id 전체와 다르다 (빠짐·남음·중복 — 오래된 목록).
  case notFound
  /// 같은 id 의 디데이나 폴더가 이미 있다 (추가).
  case alreadyExists
  /// 저장소를 열거나 읽지 못했다. 다시 시도하면 성공할 수 있다.
  case loadFailed
  /// 저장하지 못했다 (디스크 부족 등). 이 호출의 변경은 하나도 남지 않는다.
  case saveFailed
  /// 폴더 이름이 규칙(`FolderNameRule`)에 맞지 않거나, 그 폴더가 받을 수 없는 `.system` 이름이다.
  case invalidFolderName
}
