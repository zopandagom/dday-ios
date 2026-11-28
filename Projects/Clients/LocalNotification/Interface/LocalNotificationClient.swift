/// 로컬 알림: 권한 상태·요청, 이 앱의 대기 요청 교체, 알림 설정 화면 열기.
public protocol LocalNotificationClient: Sendable {
  /// 지금 권한 상태. 실패하는 API 가 아니다.
  func authorizationStatus() async -> NotificationAuthorization
  /// 알림·소리 권한을 요청하고(미결정이면 시스템 프롬프트, 사용자가 고를 때까지 돌아오지 않는다) 요청 뒤 상태를 돌려준다.
  /// 이미 정해진 상태에서 부르면 프롬프트가 뜰 수 있으므로 부르는 쪽이 `.notDetermined` 일 때만 부른다.
  /// 시스템 에러는 로그에 남기고 다시 읽은 상태를 돌려준다 (던지지 않는다).
  func requestAuthorization() async -> NotificationAuthorization
  /// 이 앱의 대기 요청을 모두 지우고 `requests` 를 그 순서로 추가한다. 앞에서 `LocalNotificationLimits.maximumPendingCount`
  /// 개까지만 쓴다. 빈 배열이면 지우기만 한다. 하나라도 추가에 실패하면 나머지를 끝까지 추가한 뒤 `.scheduleFailed`.
  /// 부르는 쪽이 겹치지 않게 한 번에 하나씩 부른다. 취소는 보지 않는다.
  func replacePending(_ requests: [NotificationRequest]) async throws(LocalNotificationError)
  /// 이 앱의 알림 설정 화면(설정 앱)을 연다. 열었으면 true, URL 을 만들 수 없거나 시스템이 열지 못하면 false.
  /// 사용자에게 따로 보이는 실패는 없다 (부르는 쪽은 결과를 화면에 쓰지 않는다).
  func openSettings() async -> Bool
}
