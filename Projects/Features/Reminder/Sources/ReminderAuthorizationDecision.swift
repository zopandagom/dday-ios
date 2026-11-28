import LocalNotificationInterface

/// 회차 안에서 권한 상태로 무엇을 할지 (순수 함수). 요청은 미결정이면서 요청 바람이 있을 때만 낸다:
/// 정해진 상태(임시 허용 포함)에서 요청하면 시스템 프롬프트가 뜰 수 있기 때문이다.
enum ReminderAuthorizationDecision: Equatable, Sendable {
  /// 시스템 프롬프트로 요청한다 (그 뒤 받은 상태로 `decide(status:, wantsRequest: false)` 를 다시 부른다).
  case requestAuthorization
  /// 저장소를 읽고 예약한다.
  case schedule
  /// 대기 요청을 비운다 (예약할 수 없는 상태).
  case clear

  static func decide(status: NotificationAuthorization, wantsRequest: Bool) -> Self {
    switch status {
    case .authorized, .provisional: .schedule
    case .notDetermined: wantsRequest ? .requestAuthorization : .clear
    case .denied: .clear
    }
  }
}
