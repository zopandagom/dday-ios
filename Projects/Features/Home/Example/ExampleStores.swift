import DDayStoreInterface
import DDayStoreTesting
import Foundation

/// 불러오기는 Fake 에 맡기고 삭제는 항상 `.saveFailed` 로 실패하는 저장소 (삭제 실패 시나리오).
final class DeleteFailingStore: DDayStoreClient {
  private let base: DDayStoreClientFake

  init(base: DDayStoreClientFake) {
    self.base = base
  }

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try await self.base.fetchAll()
  }

  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.base.add(draft)
  }

  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try await self.base.update(id: id, draft)
  }

  func delete(id _: UUID) async throws(DDayStoreError) {
    throw .saveFailed
  }

  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try await self.base.fetchPhoto(id: id)
  }
}

/// `fetchAll`·`fetchPhoto` 가 돌아오지 않는 저장소 (로딩 화면 Preview). 쓰기는 모두 `.saveFailed`.
final class NeverEndingStore: DDayStoreClient {
  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try await Self.waitForever()
  }

  func fetchPhoto(id _: UUID) async throws(DDayStoreError) -> Data? {
    try await Self.waitForever()
  }

  /// 끝나지 않는 스트림을 기다린다. continuation 을 붙잡아 두어 스트림이 끝나지 않게 한다.
  private static func waitForever<T>() async throws(DDayStoreError) -> T {
    let (stream, continuation) = AsyncStream.makeStream(of: Never.self)
    for await _ in stream {}
    withExtendedLifetime(continuation) {}
    // 기다리던 Task 가 취소되면 여기로 온다.
    throw .loadFailed
  }

  func add(_: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func update(id _: UUID, _: DDayDraft) async throws(DDayStoreError) -> DDay {
    throw .saveFailed
  }

  func delete(id _: UUID) async throws(DDayStoreError) {
    throw .saveFailed
  }
}

/// 압축본 읽기(`fetchPhoto`)만 `delay` 만큼 늦게 끝나는 저장소 (느린 압축본 읽기 시나리오). 나머지는 `base` 그대로.
final class SlowPhotoStore: DDayStoreClient {
  private let base: any DDayStoreClient
  private let delay: Duration

  init(base: any DDayStoreClient, delay: Duration) {
    self.base = base
    self.delay = delay
  }

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

  /// 기다린 뒤 그때의 `base` 를 읽는다 (실제 저장소처럼 끝날 때의 상태를 돌려준다). 취소는 보지 않는다.
  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try? await Task.sleep(for: self.delay)
    return try await self.base.fetchPhoto(id: id)
  }
}

/// 압축본 읽기(`fetchPhoto`)만 늘 `.loadFailed` 로 실패하는 저장소 (압축본 읽기 실패 시나리오). 나머지는 `base` 그대로.
final class PhotoReadFailingStore: DDayStoreClient {
  private let base: any DDayStoreClient

  init(base: any DDayStoreClient) {
    self.base = base
  }

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

  func fetchPhoto(id _: UUID) async throws(DDayStoreError) -> Data? {
    throw .loadFailed
  }
}
