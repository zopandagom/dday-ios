import DDayStoreInterface
import DDayStoreTesting
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting

/// 매번 `failNextReplace` 를 다시 걸어 교체가 늘 `.scheduleFailed` 로 끝나는 알림 클라이언트 (예약 실패 시나리오).
/// 나머지는 Fake 에 맡긴다. Fake 규칙대로 지우고 추가는 한 뒤 실패를 던진다.
final class ReplaceFailingNotificationClient: LocalNotificationClient {
  private let base: LocalNotificationClientFake

  init(base: LocalNotificationClientFake) {
    self.base = base
  }

  func authorizationStatus() async -> NotificationAuthorization {
    await self.base.authorizationStatus()
  }

  func requestAuthorization() async -> NotificationAuthorization {
    await self.base.requestAuthorization()
  }

  func replacePending(_ requests: [NotificationRequest]) async throws(LocalNotificationError) {
    self.base.failNextReplace()
    try await self.base.replacePending(requests)
  }

  func openSettings() async -> Bool {
    await self.base.openSettings()
  }
}

/// `fetchAll` 이 늘 `.loadFailed` 로 실패하고 나머지는 Fake 에 맡기는 저장소 (저장소 읽기 실패 시나리오).
final class LoadFailingStore: DDayStoreClient {
  private let base: DDayStoreClientFake

  init(base: DDayStoreClientFake) {
    self.base = base
  }

  func fetchAll() async throws(DDayStoreError) -> [DDay] {
    throw .loadFailed
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
}
