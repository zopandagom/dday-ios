import Foundation
import LocalNotificationInterface
import Synchronization

enum ControlledNotificationError: Error {
  /// 기다리는 호출이 없는데 resume 했다.
  case nothingPending
  /// 상한(약 1초)까지 기다려도 조건이 되지 않았다.
  case timedOut(String)
}

/// `replacePending`·`requestAuthorization` 이 테스트가 `resume…` 할 때까지 멈추는 알림 클라이언트. 호출은 순서대로 `calls` 에 남는다.
/// `authorizationStatus` 는 지금 상태를 바로 돌려주고, `openSettings` 는 횟수만 세고 true 를 바로 돌려준다.
/// 겹침(회차 중 이벤트, 프롬프트 중 복귀) 테스트용이다. 각 테스트는 시작한 호출을 모두 resume 한다.
/// continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다 (FolderManager 의 `ControlledFolderStore` 와 같은 방식).
final class ControlledNotificationClient: LocalNotificationClient {
  enum Call: Equatable {
    case requestAuthorization
    case replace([NotificationRequest])
  }

  private struct State {
    var status: NotificationAuthorization
    var calls: [Call] = []
    var openSettingsCount = 0
    var pendingAuthorizations: [CheckedContinuation<NotificationAuthorization, Never>] = []
    var pendingReplaces: [CheckedContinuation<Result<Void, LocalNotificationError>, Never>] = []
  }

  private let state: Mutex<State>

  init(status: NotificationAuthorization = .authorized) {
    self.state = Mutex(State(status: status))
  }

  var calls: [Call] {
    self.state.withLock { $0.calls }
  }

  /// `replacePending` 에 넘긴 목록 (호출 순서).
  var replaces: [[NotificationRequest]] {
    self.calls.compactMap { call in
      if case let .replace(requests) = call {
        requests
      } else {
        nil
      }
    }
  }

  var requestAuthorizationCount: Int {
    self.calls.count(where: { $0 == .requestAuthorization })
  }

  var openSettingsCount: Int {
    self.state.withLock { $0.openSettingsCount }
  }

  // MARK: - LocalNotificationClient

  func authorizationStatus() async -> NotificationAuthorization {
    self.state.withLock { $0.status }
  }

  func requestAuthorization() async -> NotificationAuthorization {
    await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(.requestAuthorization)
        state.pendingAuthorizations.append(continuation)
      }
    }
  }

  func replacePending(_ requests: [NotificationRequest]) async throws(LocalNotificationError) {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(.replace(requests))
        state.pendingReplaces.append(continuation)
      }
    }
    try result.get()
  }

  func openSettings() async -> Bool {
    self.state.withLock { $0.openSettingsCount += 1 }
    return true
  }

  // MARK: - 테스트 조작

  /// 가장 먼저 멈춘 `requestAuthorization` 을 끝낸다. 지금 상태를 `status` 로 바꾸고 그 값을 돌려준다 (사용자가 고른 것처럼).
  func resumeAuthorization(with status: NotificationAuthorization) throws {
    let continuation = self.state.withLock { state in
      state.status = status
      return state.pendingAuthorizations.isEmpty ? nil : state.pendingAuthorizations.removeFirst()
    }
    guard let continuation else { throw ControlledNotificationError.nothingPending }
    continuation.resume(returning: status)
  }

  /// 가장 먼저 멈춘 `replacePending` 을 끝낸다 (`fails` 면 `.scheduleFailed`).
  func resumeReplace(fails: Bool = false) throws {
    let continuation = self.state.withLock { state in
      state.pendingReplaces.isEmpty ? nil : state.pendingReplaces.removeFirst()
    }
    guard let continuation else { throw ControlledNotificationError.nothingPending }
    continuation.resume(returning: fails ? .failure(.scheduleFailed) : .success(()))
  }

  /// 멈춘 `replacePending` 이 생길 때까지 기다린다.
  func waitForPendingReplace() async throws {
    try await self.waitUntil("replace") { !$0.pendingReplaces.isEmpty }
  }

  /// 멈춘 `requestAuthorization` 이 생길 때까지 기다린다.
  func waitForPendingAuthorization() async throws {
    try await self.waitUntil("authorization") { !$0.pendingAuthorizations.isEmpty }
  }

  /// 최대 1000 회 확인한다: 처음 100 회는 `Task.yield()`, 그 뒤는 1ms 씩 (합계 약 1초). 넘으면 `timedOut`.
  private func waitUntil(_ label: String, _ condition: (State) -> Bool) async throws {
    for attempt in 0 ..< 1000 {
      if self.state.withLock({ condition($0) }) {
        return
      }
      if attempt < 100 {
        await Task.yield()
      } else {
        try await Task.sleep(for: .milliseconds(1))
      }
    }
    throw ControlledNotificationError.timedOut(label)
  }
}
