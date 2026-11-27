import DDayStoreInterface
import Foundation
import Synchronization

enum ControlledStoreError: Error {
  /// 기다리는 호출이 없는데 resume 했다.
  case nothingPending
  /// 상한(약 1초)까지 기다려도 조건이 되지 않았다.
  case timedOut(String)
}

/// 폴더 쓰기 4개가 테스트가 `resume…` 할 때까지 멈추는 저장소. 호출은 순서대로 `calls` 에 남는다.
/// 나머지 메서드는 즉시 빈 값을 돌려준다 (`add`·`update` 는 `.saveFailed`: 이 테스트들은 부르지 않는다).
/// 겹침(저장 중 이벤트, 두 번 탭) 테스트용이다. 각 테스트는 시작한 호출을 모두 resume 한다.
/// continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다 (Home 의 `ControlledDDayStore` 와 같은 방식).
final class ControlledFolderStore: DDayStoreClient {
  enum Call: Equatable {
    case add(DDayFolderDraft)
    case update(UUID, DDayFolderDraft)
    case move([UUID])
    case delete(UUID, FolderDeletion)
  }

  private struct State {
    var calls: [Call] = []
    var pendingFolders: [CheckedContinuation<Result<DDayFolder, DDayStoreError>, Never>] = []
    var pendingMoves: [CheckedContinuation<Result<[DDayFolder], DDayStoreError>, Never>] = []
    var pendingDeletes: [CheckedContinuation<Result<[UUID], DDayStoreError>, Never>] = []
  }

  private let state = Mutex(State())

  var calls: [Call] {
    self.state.withLock { $0.calls }
  }

  // MARK: - DDayStoreClient

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    []
  }

  func add(_: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func update(id _: UUID, _: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func delete(id _: UUID) async throws(DDayStoreError) {}

  func fetchPhoto(id _: UUID) async throws(DDayStoreError) -> Data? {
    nil
  }

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    []
  }

  func addFolder(_ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try await self.holdFolder(.add(draft))
  }

  func updateFolder(id: UUID, _ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try await self.holdFolder(.update(id, draft))
  }

  func moveFolders(_ orderedIDs: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(.move(orderedIDs))
        state.pendingMoves.append(continuation)
      }
    }
    return try result.get()
  }

  func deleteFolder(id: UUID, dDays: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(.delete(id, dDays))
        state.pendingDeletes.append(continuation)
      }
    }
    return try result.get()
  }

  // MARK: - 테스트 조작

  /// 가장 먼저 멈춘 `addFolder`·`updateFolder` 를 `result` 로 끝낸다.
  func resumeFolder(with result: Result<DDayFolder, DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingFolders.isEmpty ? nil : state.pendingFolders.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 가장 먼저 멈춘 `moveFolders` 를 `result` 로 끝낸다.
  func resumeMove(with result: Result<[DDayFolder], DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingMoves.isEmpty ? nil : state.pendingMoves.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 가장 먼저 멈춘 `deleteFolder` 를 `result` 로 끝낸다.
  func resumeDelete(with result: Result<[UUID], DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingDeletes.isEmpty ? nil : state.pendingDeletes.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 멈춘 `addFolder`·`updateFolder` 가 생길 때까지 기다린다.
  func waitForPendingFolder() async throws {
    try await self.waitUntil("folder") { !$0.pendingFolders.isEmpty }
  }

  /// 멈춘 `moveFolders` 가 생길 때까지 기다린다.
  func waitForPendingMove() async throws {
    try await self.waitUntil("move") { !$0.pendingMoves.isEmpty }
  }

  /// 멈춘 `deleteFolder` 가 생길 때까지 기다린다.
  func waitForPendingDelete() async throws {
    try await self.waitUntil("delete") { !$0.pendingDeletes.isEmpty }
  }

  private func holdFolder(_ call: Call) async throws(DDayStoreError) -> DDayFolder {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.calls.append(call)
        state.pendingFolders.append(continuation)
      }
    }
    return try result.get()
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
