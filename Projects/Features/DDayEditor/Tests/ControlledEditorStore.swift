import DDayStoreInterface
import Foundation
import Synchronization

enum ControlledStoreError: Error {
  /// 기다리는 호출이 없는데 resume 했다.
  case nothingPending
  /// 상한(약 1초)까지 기다려도 조건이 되지 않았다.
  case timedOut(String)
}

/// 호출 중간에 멈추는 저장소. `add`·`update`·`delete` 는 호출을 기록하고, 테스트가 `resume…` 할 때까지 멈춘다.
/// 겹침(저장·삭제 진행 중 이벤트) 테스트용이다. 각 테스트는 시작한 호출을 모두 resume 한다.
/// continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다.
final class ControlledEditorStore: DDayStoreClient {
  enum Call: Equatable {
    case add(DDayDraft)
    case update(UUID, DDayDraft)
    case delete(UUID)
  }

  private struct State {
    var calls: [Call] = []
    var pendingWrites: [CheckedContinuation<Result<DDay, DDayStoreError>, Never>] = []
    var pendingDeletes: [CheckedContinuation<Result<Void, DDayStoreError>, Never>] = []
  }

  private let state = Mutex(State())

  var calls: [Call] {
    self.state.withLock { $0.calls }
  }

  // MARK: - DDayStoreClient

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    []
  }

  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.write(.add(draft))
  }

  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.write(.update(id, draft))
  }

  func fetchPhoto(id _: UUID) async throws(DDayStoreError) -> Data? {
    nil
  }

  func delete(id: UUID) async throws(DDayStoreError) {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(.delete(id))
        state.pendingDeletes.append(continuation)
      }
    }
    if case let .failure(error) = result {
      throw error
    }
  }

  private func write(_ call: Call) async throws(DDayStoreError) -> DDay {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(call)
        state.pendingWrites.append(continuation)
      }
    }
    switch result {
    case let .success(dDay): return dDay
    case let .failure(error): throw error
    }
  }

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    []
  }

  // 폴더 쓰기는 이 테스트들이 부르지 않는다.
  func addFolder(_: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    throw .loadFailed
  }

  func updateFolder(id _: UUID, _: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    throw .loadFailed
  }

  func moveFolders(_: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    throw .loadFailed
  }

  func deleteFolder(id _: UUID, dDays _: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    throw .loadFailed
  }

  // MARK: - 테스트 조작

  /// 가장 먼저 멈춘 `add`·`update` 를 `result` 로 끝낸다.
  func resumeWrite(with result: Result<DDay, DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingWrites.isEmpty ? nil : state.pendingWrites.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 가장 먼저 멈춘 `delete` 를 `result` 로 끝낸다.
  func resumeDelete(with result: Result<Void, DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingDeletes.isEmpty ? nil : state.pendingDeletes.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  func waitForPendingWrite() async throws {
    try await self.waitUntil("write") { !$0.pendingWrites.isEmpty }
  }

  func waitForPendingDelete() async throws {
    try await self.waitUntil("delete") { !$0.pendingDeletes.isEmpty }
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
