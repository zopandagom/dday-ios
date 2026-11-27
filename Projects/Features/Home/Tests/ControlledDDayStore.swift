import DDayStoreInterface
import Foundation
import Synchronization

enum ControlledStoreError: Error {
  /// 기다리는 호출이 없는데 resume 했다.
  case nothingPending
  /// 상한(약 1초)까지 기다려도 조건이 되지 않았다.
  case timedOut(String)
}

/// 호출 중간에 멈추는 저장소. `fetchAll`·`delete` 는 호출을 기록하고, 테스트가 `resume…` 할 때까지 멈춘다.
/// 겹침(불러오는 중 재호출, 삭제 진행 중 이벤트) 테스트용이다. 각 테스트는 시작한 호출을 모두 resume 한다.
/// continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다.
final class ControlledDDayStore: DDayStoreClient {
  private struct State {
    var fetchAllCallCount = 0
    var deleteCallIDs: [UUID] = []
    var pendingFetches: [CheckedContinuation<Result<[DDay], DDayStoreError>, Never>] = []
    var pendingDeletes: [UUID: [CheckedContinuation<Result<Void, DDayStoreError>, Never>]] = [:]
  }

  private let state = Mutex(State())

  var fetchAllCallCount: Int {
    self.state.withLock { $0.fetchAllCallCount }
  }

  var deleteCallIDs: [UUID] {
    self.state.withLock { $0.deleteCallIDs }
  }

  // MARK: - DDayStoreClient

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.fetchAllCallCount += 1
        state.pendingFetches.append(continuation)
      }
    }
    switch result {
    case let .success(dDays): return dDays
    case let .failure(error): throw error
    }
  }

  func add(_: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func update(id _: UUID, _: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func fetchPhoto(id _: UUID) async throws(DDayStoreError) -> Data? {
    nil
  }

  func delete(id: UUID) async throws(DDayStoreError) {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.deleteCallIDs.append(id)
        state.pendingDeletes[id, default: []].append(continuation)
      }
    }
    if case let .failure(error) = result {
      throw error
    }
  }

  // MARK: - 테스트 조작

  /// 가장 먼저 멈춘 `fetchAll` 을 `result` 로 끝낸다.
  func resumeFetch(with result: Result<[DDay], DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingFetches.isEmpty ? nil : state.pendingFetches.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 그 id 로 가장 먼저 멈춘 `delete` 를 `result` 로 끝낸다.
  func resumeDelete(id: UUID, with result: Result<Void, DDayStoreError>) throws {
    let continuation = self.state.withLock { state -> CheckedContinuation<Result<Void, DDayStoreError>, Never>? in
      guard var pending = state.pendingDeletes[id], !pending.isEmpty else { return nil }
      let first = pending.removeFirst()
      state.pendingDeletes[id] = pending.isEmpty ? nil : pending
      return first
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 멈춘 `fetchAll` 이 `count` 개 이상이 될 때까지 기다린다.
  func waitForPendingFetches(_ count: Int = 1) async throws {
    try await self.waitUntil("fetch \(count)개") { $0.pendingFetches.count >= count }
  }

  /// 그 id 의 `delete` 가 멈출 때까지 기다린다.
  func waitForPendingDelete(id: UUID) async throws {
    try await self.waitUntil("delete \(id)") { $0.pendingDeletes[id]?.isEmpty == false }
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
    throw ControlledStoreError.timedOut(label)
  }
}
