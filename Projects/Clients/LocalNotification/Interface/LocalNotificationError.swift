/// 로컬 알림 에러. 프레임워크 에러가 새어 나가지 않도록 연관값을 두지 않는다 (원인 코드는 Impl 로그에만).
public enum LocalNotificationError: Error, Equatable, Sendable {
  /// 대기 요청 추가가 하나 이상 실패했다. 실패하지 않은 요청은 들어가 있다.
  case scheduleFailed
}

/// iOS 가 앱마다 남기는 대기 알림 최대 수. 넘게 추가하면 에러 없이 **먼저 추가한 것부터** 사라진다
/// (시뮬레이터 실행 값: 70개 추가 → 대기 64개, 처음 6개가 빠짐).
public enum LocalNotificationLimits {
  public static let maximumPendingCount = 64
}
