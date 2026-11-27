/// 사진 처리 에러. 프레임워크 에러가 새어 나가지 않도록 연관값을 두지 않는다 (원인 종류는 Impl 로그에만).
public enum PhotoError: Error, Equatable, Sendable {
  /// 원본을 읽지 못함 (선택기 로드 실패·nil, 내려받기 실패, 취소).
  case readFailed
  /// 이미지가 아니거나 디코딩 실패, 크기 정보 없음.
  case decodeFailed
  /// 바이트·픽셀 한도 초과.
  case tooLarge
  /// 자르기·그리기·JPEG 인코딩 실패.
  case renderFailed
}
