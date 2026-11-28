import LocalNotificationInterface
import Testing
@testable import ReminderFeature

/// 권한 분기 (§4.2 표 7행).
struct ReminderAuthorizationDecisionTests {
  @Test(
    "권한 상태와 요청 바람으로 요청·예약·비우기를 고른다",
    arguments: [
      (NotificationAuthorization.authorized, false, ReminderAuthorizationDecision.schedule),
      (.authorized, true, .schedule),
      (.provisional, false, .schedule),
      (.provisional, true, .schedule),
      (.notDetermined, true, .requestAuthorization),
      (.notDetermined, false, .clear),
      (.denied, false, .clear),
      (.denied, true, .clear),
    ]
  )
  func decide(status: NotificationAuthorization, wantsRequest: Bool, expected: ReminderAuthorizationDecision) {
    #expect(ReminderAuthorizationDecision.decide(status: status, wantsRequest: wantsRequest) == expected)
  }
}
