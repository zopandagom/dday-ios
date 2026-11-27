import DDayStoreInterface
import DDayStoreTesting
import Foundation

/// 삭제만 항상 `.saveFailed` 로 실패하고 나머지는 Fake 에 맡기는 저장소 (삭제 실패 시나리오).
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

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    try await self.base.fetchFolders()
  }
}

/// 쓰기마다 2초 기다린 뒤 Fake 에 맡기는 저장소 (중복 탭·끌어내리기 막힘 확인).
final class SlowStore: DDayStoreClient {
  private let base: DDayStoreClientFake

  init(base: DDayStoreClientFake) {
    self.base = base
  }

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try await self.base.fetchAll()
  }

  func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    await Self.wait()
    return try await self.base.add(draft)
  }

  func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    await Self.wait()
    return try await self.base.update(id: id, draft)
  }

  func delete(id: UUID) async throws(DDayStoreError) {
    await Self.wait()
    try await self.base.delete(id: id)
  }

  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try await self.base.fetchPhoto(id: id)
  }

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    try await self.base.fetchFolders()
  }

  private static func wait() async {
    try? await Task.sleep(for: .seconds(2))
  }
}
