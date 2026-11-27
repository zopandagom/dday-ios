import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Synchronization

/// `fetchPhoto` 만 멈추는 저장소. `fetchPhoto` 는 호출 id 를 기록하고, 테스트가 `resumeFetchPhoto` 할 때까지 멈춘다.
/// 멈춘 호출은 시작한 순서대로 쌓이고, `resumeFetchPhoto(at:)` 로 끝낼 차례를 고를 수 있다 (늦게 온 옛 결과 테스트용).
/// 그 밖의 메서드는 안에 둔 `DDayStoreClientFake` 에 넘긴다. 각 테스트는 시작한 호출을 모두 resume 한다.
/// continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다.
final class ControlledPhotoStore: DDayStoreClient {
  private struct State {
    var fetchPhotoCallIDs: [UUID] = []
    var pendingFetchPhotos: [CheckedContinuation<Result<Data?, DDayStoreError>, Never>] = []
  }

  private let state = Mutex(State())
  private let base: DDayStoreClientFake

  init(base: DDayStoreClientFake = DDayStoreClientFake()) {
    self.base = base
  }

  /// `fetchPhoto` 를 부른 id (부른 순서).
  var fetchPhotoCallIDs: [UUID] {
    self.state.withLock { $0.fetchPhotoCallIDs }
  }

  /// 아직 끝나지 않은 `fetchPhoto` 수.
  var pendingFetchPhotoCount: Int {
    self.state.withLock { $0.pendingFetchPhotos.count }
  }

  // MARK: - DDayStoreClient

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try await self.base.fetchAll()
  }

  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.base.add(draft)
  }

  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.base.update(id: id, draft)
  }

  func delete(id: UUID) async throws(DDayStoreError) {
    try await self.base.delete(id: id)
  }

  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.fetchPhotoCallIDs.append(id)
        state.pendingFetchPhotos.append(continuation)
      }
    }
    switch result {
    case let .success(data): return data
    case let .failure(error): throw error
    }
  }

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    try await self.base.fetchFolders()
  }

  func addFolder(_ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try await self.base.addFolder(draft)
  }

  func updateFolder(id: UUID, _ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try await self.base.updateFolder(id: id, draft)
  }

  func moveFolders(_ orderedIDs: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    try await self.base.moveFolders(orderedIDs)
  }

  func deleteFolder(id: UUID, dDays: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    try await self.base.deleteFolder(id: id, dDays: dDays)
  }

  // MARK: - 테스트 조작

  /// 멈춘 `fetchPhoto` 중 `index` 번째(시작 순서, 0 이 가장 먼저)를 `result` 로 끝낸다.
  func resumeFetchPhoto(at index: Int = 0, with result: Result<Data?, DDayStoreError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingFetchPhotos.indices.contains(index) ? state.pendingFetchPhotos.remove(at: index) : nil
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 멈춘 `fetchPhoto` 가 `count` 개 이상이 될 때까지 기다린다.
  func waitForPendingFetchPhotos(_ count: Int = 1) async throws {
    for attempt in 0 ..< 1000 {
      if self.state.withLock({ $0.pendingFetchPhotos.count >= count }) {
        return
      }
      if attempt < 100 {
        await Task.yield()
      } else {
        try await Task.sleep(for: .milliseconds(1))
      }
    }
    throw ControlledStoreError.timedOut("fetchPhoto \(count)개")
  }
}
