import Core
import DDayStoreInterface
import Foundation
import SwiftData

/// 폴더 쓰기 (`addFolder`·`updateFolder`·`moveFolders`·`deleteFolder`). 각각 컨텍스트 하나에 save 한 번이라 실패하면
/// 이 호출의 변경은 하나도 남지 않는다 (`save` 가 rollback). 결과는 저장 전 fetch 로 다시 만들지 않고 넣은 값으로 만든다.
public extension DDayStoreClientImpl {
  @concurrent
  func addFolder(_ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    let context = try await self.makeContext()
    // 추가는 기본 폴더 키가 없으므로 `.system` 은 늘 거부한다.
    let customName = try Self.validatedCustomName(draft.name, allowedSystemKey: nil)
    let id = self.makeID()
    // `@Attribute(.unique)` 는 같은 id 삽입을 에러 없이 덮어쓰므로(upsert) 먼저 확인한다.
    var existing = FetchDescriptor<DDayFolderRecord>(predicate: #Predicate { $0.id == id })
    existing.fetchLimit = 1
    let existingCount: Int
    do {
      existingCount = try context.fetchCount(existing)
    } catch {
      Self.logFailure("addFolder", error)
      throw DDayStoreError.loadFailed
    }
    guard existingCount == 0 else { throw DDayStoreError.alreadyExists }
    let timestamp = self.now()
    // 맨 뒤: 읽을 수 없는 행을 포함한 모든 폴더 행의 순서 최댓값 + 1, 행이 없으면 0.
    let records = try Self.fetchFolderRecords(in: context, operation: "addFolder")
    let sortOrder = (records.map(\.sortOrder).max() ?? -1) + 1
    let fields = DDayFolderRecordFields(
      id: id,
      systemKey: nil,
      customName: customName,
      colorKey: DDayFolderMapping.string(for: draft.color),
      iconKey: DDayFolderMapping.string(for: draft.icon),
      sortOrder: sortOrder,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    // 쓰기 문자열을 거꾸로 찾으므로 nil 이 될 수 없지만, 강제 언래핑 대신 저장 전에 확인한다 (남는 변경 없음).
    guard let folder = DDayFolderMapping.folder(from: fields) else {
      Self.logger.error("DDayStore addFolder unreadable new row")
      throw DDayStoreError.loadFailed
    }
    context.insert(DDayFolderRecord(fields))
    try Self.save(context, operation: "addFolder")
    return folder
  }

  @concurrent
  func updateFolder(id: UUID, _ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    let context = try await self.makeContext()
    guard let record = try Self.fetchFolderRecord(id: id, in: context, operation: "updateFolder") else {
      throw DDayStoreError.notFound
    }
    let customName = try Self.validatedCustomName(draft.name, allowedSystemKey: record.systemKey)
    let timestamp = self.now()
    // `systemKey`·`sortOrder`·`createdAt` 는 그대로 (기본 폴더 키는 이름을 바꿔도 남긴다). 읽을 수 없던 행도 고쳐질 수 있다.
    record.customName = customName
    record.colorKey = DDayFolderMapping.string(for: draft.color)
    record.iconKey = DDayFolderMapping.string(for: draft.icon)
    record.updatedAt = timestamp
    // 모르는 systemKey 행의 `.system` 은 검증이 이미 거부하므로 정상적으로는 nil 이 아니다. 컨텍스트는 저장하지 않고 버린다.
    guard let folder = DDayFolderMapping.folder(from: record.fields) else {
      Self.logger.error("DDayStore updateFolder unreadable row")
      throw DDayStoreError.loadFailed
    }
    try Self.save(context, operation: "updateFolder")
    return folder
  }

  @concurrent
  func moveFolders(_ orderedIDs: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    let context = try await self.makeContext()
    let records = try Self.fetchFolderRecords(in: context, operation: "moveFolders")
    var readable: [UUID: (record: DDayFolderRecord, folder: DDayFolder)] = [:]
    for record in records {
      if let folder = DDayFolderMapping.folder(from: record.fields) {
        readable[record.id] = (record, folder)
      }
    }
    // 겹침은 개수 비교로 걸린다. 읽을 수 없는 행은 목록에 없어야 한다 (화면에 보이지 않는다).
    guard orderedIDs.count == readable.count, Set(orderedIDs) == Set(readable.keys) else {
      throw DDayStoreError.notFound
    }
    var folders: [DDayFolder] = []
    for (index, id) in orderedIDs.enumerated() {
      guard let entry = readable[id] else { throw DDayStoreError.notFound }
      // 값이 같아도 대입한다. 순서는 폴더 내용 수정이 아니라 `updatedAt` 은 바꾸지 않는다.
      entry.record.sortOrder = index
      folders.append(entry.folder)
    }
    // 읽을 수 없는 행의 순서는 그대로 둔다 (`fetchFolders` 에서 빠지고, 새 폴더는 최댓값 + 1 이라 맨 뒤).
    try Self.save(context, operation: "moveFolders")
    return folders
  }

  @concurrent
  func deleteFolder(id: UUID, dDays deletion: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    let context = try await self.makeContext()
    // 읽을 수 없는 폴더 행도 지울 수 있다 (화면에 보이지 않아 정상 흐름에서는 오지 않는다).
    guard let folderRecord = try Self.fetchFolderRecord(id: id, in: context, operation: "deleteFolder") else {
      throw DDayStoreError.notFound
    }
    let target: UUID? = id
    let records: [DDayRecord]
    do {
      records = try context.fetch(FetchDescriptor<DDayRecord>(predicate: #Predicate { $0.folderID == target }))
    } catch {
      Self.logFailure("deleteFolder", error)
      throw DDayStoreError.loadFailed
    }
    var deleted: [(createdAt: Date, id: UUID)] = []
    var keptCount = 0
    for record in records {
      let isReadable = DDayRecordMapping.dDay(from: record.fields, folderIDs: []) != nil
      if deletion == .delete, isReadable {
        if let photoRecord = try Self.fetchPhotoRecord(dDayID: record.id, in: context, operation: "deleteFolder") {
          context.delete(photoRecord)
        }
        deleted.append((record.createdAt, record.id))
        context.delete(record)
      } else {
        // 미분류로 옮긴다. 홈이 들고 있는 값과 어긋나지 않게 `updatedAt` 은 바꾸지 않는다.
        // 읽을 수 없는 행은 `.delete` 에서도 지우지 않는다 (나중 버전이 읽을 수 있게).
        if !isReadable {
          keptCount += 1
        }
        record.folderID = nil
      }
    }
    if deletion == .delete, keptCount > 0 {
      Self.logger.error("DDayStore deleteFolder kept \(keptCount) unreadable rows")
    }
    context.delete(folderRecord)
    try Self.save(context, operation: "deleteFolder")
    // `fetchAll` 순서 (생성 시각, 같으면 id 문자열 오름차순).
    return deleted.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }.map(\.id)
  }

  // MARK: - 내부

  private static func fetchFolderRecord(
    id: UUID,
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> DDayFolderRecord? {
    var descriptor = FetchDescriptor<DDayFolderRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    do {
      return try context.fetch(descriptor).first
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
  }

  /// 읽을 수 없는 행을 포함한 모든 폴더 행.
  private static func fetchFolderRecords(
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> [DDayFolderRecord] {
    do {
      return try context.fetch(FetchDescriptor<DDayFolderRecord>())
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
  }

  /// 저장할 `customName`. `.custom` 은 `FolderNameRule` 로 정리한 이름, `.system(key)` 는 행의 기본 폴더 키가
  /// `allowedSystemKey` 와 같을 때만 nil(기본 이름으로 보임). 그 밖은 `.invalidFolderName`.
  private static func validatedCustomName(
    _ name: FolderName,
    allowedSystemKey: String?
  ) throws(DDayStoreError) -> String? {
    switch name {
    case let .custom(text):
      guard case let .valid(normalized) = FolderNameRule.validate(text) else {
        throw DDayStoreError.invalidFolderName
      }
      return normalized
    case let .system(folder):
      guard let allowedSystemKey, DDayFolderMapping.string(for: folder) == allowedSystemKey else {
        throw DDayStoreError.invalidFolderName
      }
      return nil
    }
  }
}
