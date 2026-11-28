import Core
import DDayStoreInterface
import Foundation
import LocalNotificationInterface
import Observation

/// 로컬 알림 예약 흐름의 상태와 로직. App(또는 Example)이 만들어 소유한다. 화면은 없다.
///
/// - 다시 예약: 앱 실행·앱 복귀·디데이 변경 때마다 저장소 전체를 읽어 Core 계획기(가까운 순 최대 60)로 요청 목록을 만들고,
///   이 앱의 대기 요청을 모두 지운 뒤 새로 넣는다 (`LocalNotificationClient.replacePending`). 지난번과 같아도 건너뛰지 않는다.
/// - 회차는 한 번에 하나만 돈다 (`ReminderSchedulePass`): 도는 중에 온 요청은 바로 돌아가고, 지금 회차가 끝나면 한 번만 더
///   돈다. 그래서 늦게 끝난 옛 회차가 새 회차의 결과를 덮지 않는다. 처음 부른 쪽만 마지막 회차까지 기다린다.
/// - 권한: 요청은 `dDaysChanged(requestAuthorizationIfNeeded: true)` 로 온 바람이 있고 상태가 미결정일 때만, 회차당 한 번
///   (`ReminderAuthorizationDecision`). 거부·미결정이면 대기 요청을 비운다(오류가 아니다). 읽은 권한이 바뀔 때마다
///   `onAuthorizationChanged` 로 알린다 (App 이 떠 있는 편집 화면에 거부 안내를 넘긴다).
/// - 실패: 저장소를 읽지 못하면 대기 요청을 그대로 두고, 추가가 일부 실패하면 들어간 것만 남긴다. 둘 다 다음 시점에 다시
///   전체 교체한다. 사용자에게 보이는 실패는 없다.
/// - 취소는 보지 않는다: Task 가 취소돼도 회차를 끝까지 돌아 반쯤 교체된 상태를 남기지 않는다.
/// - 로그를 남기지 않는다 (제목·날짜·id 는 사용자 데이터).
@MainActor
@Observable
public final class ReminderModel {
  public enum Outcome: Equatable, Sendable {
    /// 예약함 (추가한 수).
    case scheduled(count: Int)
    /// 권한이 없어 대기 요청을 비움 (거부·미결정).
    case notAllowed
    /// 저장소를 읽지 못해 대기 요청을 건드리지 않음.
    case loadFailed
    /// 대기 요청 추가 중 하나 이상 실패.
    case scheduleFailed
  }

  /// 마지막으로 읽은 권한. 처음 읽기 전 nil.
  public private(set) var authorization: NotificationAuthorization?
  /// 회차가 도는 중.
  public private(set) var isScheduling = false
  /// 마지막 회차 결과. 처음 nil.
  public private(set) var lastOutcome: Outcome?
  /// 마지막으로 replacePending 에 넘긴 요청 (Example·테스트 확인용. 권한 없음이면 []). 저장소 읽기 실패면 그 전 값 그대로.
  public private(set) var scheduledRequests: [NotificationRequest] = []

  @ObservationIgnored private var pass = ReminderSchedulePass()
  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let notifications: any LocalNotificationClient
  @ObservationIgnored private let now: @MainActor () -> Date
  @ObservationIgnored private let timeZone: @MainActor () -> TimeZone
  @ObservationIgnored private let onAuthorizationChanged: @MainActor (NotificationAuthorization) -> Void

  /// - Parameters:
  ///   - now: 회차마다 부르는 지금 시각 (계획기의 오늘·지금).
  ///   - timeZone: 회차마다 부르는 시간대 (App 은 `.autoupdatingCurrent`).
  ///   - onAuthorizationChanged: 읽은 권한이 이전과 다를 때마다 (처음 읽을 때 포함).
  public init(
    store: any DDayStoreClient,
    notifications: any LocalNotificationClient,
    now: @escaping @MainActor () -> Date,
    timeZone: @escaping @MainActor () -> TimeZone,
    onAuthorizationChanged: @escaping @MainActor (NotificationAuthorization) -> Void = { _ in }
  ) {
    self.store = store
    self.notifications = notifications
    self.now = now
    self.timeZone = timeZone
    self.onAuthorizationChanged = onAuthorizationChanged
  }

  /// 앱 시작 (App 루트의 `.task`). 권한 요청 없음.
  public func appLaunched() async {
    await self.schedule(requestAuthorization: false)
  }

  /// 앱 복귀 (scenePhase .active). 권한 요청 없음. 설정 앱에서 바꾼 권한을 여기서 읽는다.
  public func sceneBecameActive() async {
    await self.schedule(requestAuthorization: false)
  }

  /// 디데이가 바뀜 (편집 결과·폴더 함께 삭제·홈 삭제). `requestAuthorizationIfNeeded` 면 이번 또는 다음 회차에서
  /// 상태가 미결정일 때 한 번 요청한다.
  public func dDaysChanged(requestAuthorizationIfNeeded: Bool) async {
    await self.schedule(requestAuthorization: requestAuthorizationIfNeeded)
  }

  /// 편집 화면의 [설정 열기] (App 이 편집 콜백에서 부른다). 이 앱의 알림 설정 화면을 연다. 회차·상태와 무관하고 겹쳐도 그대로 연다.
  /// 결과(Bool)는 화면에 쓰지 않는다. 돌아오면 `sceneBecameActive` 가 바뀐 권한을 읽는다.
  public func notificationSettingsRequested() async {
    _ = await self.notifications.openSettings()
  }

  // MARK: - 회차

  private func schedule(requestAuthorization: Bool) async {
    guard self.pass.requested(requestAuthorizationIfNeeded: requestAuthorization) else { return }
    self.isScheduling = true
    repeat {
      let wantsRequest = self.pass.passStarted()
      await self.runOnce(wantsRequest: wantsRequest)
    } while self.pass.passFinished()
    self.isScheduling = false
  }

  private func runOnce(wantsRequest: Bool) async {
    var status = await self.notifications.authorizationStatus()
    var decision = ReminderAuthorizationDecision.decide(status: status, wantsRequest: wantsRequest)
    if decision == .requestAuthorization {
      status = await self.notifications.requestAuthorization()
      decision = ReminderAuthorizationDecision.decide(status: status, wantsRequest: false)
    }
    self.setAuthorization(status)

    switch decision {
    case .schedule:
      await self.scheduleRequests()
    case .clear:
      await self.clearRequests()
    case .requestAuthorization:
      // 요청 뒤 판단은 늘 wantsRequest: false 라 오지 않는다.
      assertionFailure("요청 뒤 다시 요청 판단이 나왔다")
      await self.clearRequests()
    }
  }

  private func scheduleRequests() async {
    let dDays: [DDay]
    do {
      dDays = try await self.store.fetchAll()
    } catch {
      self.lastOutcome = .loadFailed
      return
    }
    let date = self.now()
    let timeZone = self.timeZone()
    let requests = ReminderRequestBuilder.requests(
      for: dDays,
      today: CalendarDay(date, in: timeZone),
      now: TimeOfDay(date, in: timeZone)
    )
    do {
      try await self.notifications.replacePending(requests)
      self.lastOutcome = .scheduled(count: requests.count)
    } catch {
      self.lastOutcome = .scheduleFailed
    }
    self.scheduledRequests = requests
  }

  /// 권한이 없으면 대기 요청이 울리지 않으므로 비우기 실패는 무시한다.
  private func clearRequests() async {
    try? await self.notifications.replacePending([])
    self.scheduledRequests = []
    self.lastOutcome = .notAllowed
  }

  private func setAuthorization(_ status: NotificationAuthorization) {
    guard self.authorization != status else { return }
    self.authorization = status
    self.onAuthorizationChanged(status)
  }
}
