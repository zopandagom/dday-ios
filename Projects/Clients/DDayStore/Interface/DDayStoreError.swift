/// 디데이 저장소 에러. 프레임워크 에러가 새어 나가지 않도록 연관값을 두지 않는다 (원인 종류는 Impl 로그에만).
public enum DDayStoreError: Error, Equatable, Sendable {
  /// 그 id 의 디데이가 없다 (수정·삭제).
  case notFound
  /// 같은 id 의 디데이가 이미 있다 (추가).
  case alreadyExists
  /// 저장소를 열거나 읽지 못했다.
  case loadFailed
  /// 저장하지 못했다 (디스크 부족 등). 이 호출의 변경은 하나도 남지 않는다.
  case saveFailed
}
