import LocalNotificationInterface
import Synchronization

/// 메모리에 대기 요청을 두는 로컬 알림 Fake. 지연·게이트는 없다 (겹침 테스트는 부르는 쪽 테스트가 따로 막는다).
///
/// - `requestAuthorization`: 횟수를 세고, 상태가 `.notDetermined` 면 `statusAfterRequest` 로 바꾼 뒤 돌려준다.
///   정해진 상태면 그대로 돌려준다.
/// - `replacePending`: 횟수를 세고 대기 요청을 비운다. 상태가 `allowsScheduling` 이 아니면 추가하지 않고, 요청이 비어
///   있지 않으면 `.scheduleFailed` (실제 시스템도 미결정 상태의 add 가 실패한다). 허용이면 앞
///   `LocalNotificationLimits.maximumPendingCount` 개를 넣는다. `failNextReplace` 를 걸었으면 그 호출은 같은 처리를
///   한 뒤 `.scheduleFailed` 를 던진다 (걸어 둔 실패는 그 한 번에 쓰인다).
/// - `openSettings`: 횟수를 세고 init 의 `opensSettings` 를 돌려준다. 상태는 바꾸지 않는다 (설정 앱에서 바꾼 것은
///   `setStatus` 로 흉내 낸다).
public final class LocalNotificationClientFake: LocalNotificationClient {
  private struct State {
    var status: NotificationAuthorization
    var requestAuthorizationCount = 0
    var pending: [NotificationRequest] = []
    var replaceCount = 0
    var failsNextReplace = false
    var openSettingsCount = 0
  }

  private let state: Mutex<State>
  private let statusAfterRequest: NotificationAuthorization
  private let opensSettings: Bool

  public init(
    status: NotificationAuthorization = .authorized,
    statusAfterRequest: NotificationAuthorization = .authorized,
    opensSettings: Bool = true
  ) {
    self.state = Mutex(State(status: status))
    self.statusAfterRequest = statusAfterRequest
    self.opensSettings = opensSettings
  }

  /// 지금 권한 상태.
  public var status: NotificationAuthorization {
    self.state.withLock { $0.status }
  }

  /// 설정 앱에서 권한을 바꾼 것처럼 상태를 바꾼다 (대기 요청은 그대로).
  public func setStatus(_ status: NotificationAuthorization) {
    self.state.withLock { $0.status = status }
  }

  /// `requestAuthorization` 을 부른 횟수.
  public var requestAuthorizationCount: Int {
    self.state.withLock { $0.requestAuthorizationCount }
  }

  /// 지금 대기 요청 (추가한 순서).
  public var pending: [NotificationRequest] {
    self.state.withLock { $0.pending }
  }

  /// `replacePending` 을 부른 횟수.
  public var replaceCount: Int {
    self.state.withLock { $0.replaceCount }
  }

  /// 다음 `replacePending` 한 번: 지우고 추가는 하되 `.scheduleFailed` 를 던진다.
  public func failNextReplace() {
    self.state.withLock { $0.failsNextReplace = true }
  }

  /// `openSettings` 를 부른 횟수.
  public var openSettingsCount: Int {
    self.state.withLock { $0.openSettingsCount }
  }

  public func authorizationStatus() async -> NotificationAuthorization {
    self.status
  }

  public func requestAuthorization() async -> NotificationAuthorization {
    self.state.withLock { state in
      state.requestAuthorizationCount += 1
      if state.status == .notDetermined {
        state.status = self.statusAfterRequest
      }
      return state.status
    }
  }

  public func replacePending(_ requests: [NotificationRequest]) async throws(LocalNotificationError) {
    let failed = self.state.withLock { state in
      state.replaceCount += 1
      let failsNext = state.failsNextReplace
      state.failsNextReplace = false
      guard state.status.allowsScheduling else {
        state.pending = []
        return failsNext || !requests.isEmpty
      }
      state.pending = Array(requests.prefix(LocalNotificationLimits.maximumPendingCount))
      return failsNext
    }
    if failed {
      throw .scheduleFailed
    }
  }

  public func openSettings() async -> Bool {
    self.state.withLock { $0.openSettingsCount += 1 }
    return self.opensSettings
  }
}
