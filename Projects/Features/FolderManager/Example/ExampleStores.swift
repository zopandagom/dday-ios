import DDayStoreInterface
import DDayStoreTesting
import Foundation

/// 폴더 쓰기 4개는 늘 `.saveFailed` 로 실패하고 나머지는 Fake 에 맡기는 저장소 (저장 실패 시나리오).
final class FolderWriteFailingStore: DDayStoreClient {
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

  func delete(id: UUID) async throws(DDayStoreError) {
    try await self.base.delete(id: id)
  }

  func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try await self.base.fetchPhoto(id: id)
  }

  func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    try await self.base.fetchFolders()
  }

  func addFolder(_: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    throw .saveFailed
  }

  func updateFolder(id _: UUID, _: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    throw .saveFailed
  }

  func moveFolders(_: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    throw .saveFailed
  }

  func deleteFolder(id _: UUID, dDays _: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    throw .saveFailed
  }
}
