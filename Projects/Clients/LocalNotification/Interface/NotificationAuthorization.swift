/// 알림 권한. UNAuthorizationStatus 의 앱이 쓰는 값만 (제한(restricted) 상태는 UserNotifications 에 없다).
public enum NotificationAuthorization: Hashable, Sendable {
  case notDetermined
  case denied
  case authorized
  /// 임시 허용(조용히 알림 센터로). 이 앱은 요청하지 않지만 상태로 오면 예약은 한다.
  case provisional

  /// 예약할 수 있는 상태 (`.authorized`·`.provisional`).
  public var allowsScheduling: Bool {
    switch self {
    case .authorized, .provisional: true
    case .notDetermined, .denied: false
    }
  }
}
