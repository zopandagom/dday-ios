import DDayStoreInterface
import Foundation
import SwiftData

/// 폴더 읽기·folderID 정규화 (`fetchFolders`·`fetchAll`·`add`·`update` 가 같은 컨텍스트에서 쓴다).
extension DDayStoreClientImpl {
  /// 읽을 수 있는 폴더 전부. 순서·생성 시각·id 문자열 오름차순. 읽지 못한 행은 빼고 그 수를 로그로 남긴다.
  static func readableFolders(
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> [DDayFolder] {
    let records: [DDayFolderRecord]
    do {
      records = try context.fetch(FetchDescriptor<DDayFolderRecord>(
        sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
      ))
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
    // 같은 순서·시각이면 id 문자열로 안정 정렬한다 (fetch 의 정렬은 그 밖의 순서를 정하지 않는다).
    let sorted = records.map(\.fields).sorted { lhs, rhs in
      if lhs.sortOrder != rhs.sortOrder {
        return lhs.sortOrder < rhs.sortOrder
      }
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
    let folders = sorted.compactMap(DDayFolderMapping.folder(from:))
    let skippedCount = sorted.count - folders.count
    if skippedCount > 0 {
      // 읽지 못한 행은 지우지 않는다 (나중 버전이 읽거나 마이그레이션할 수 있게).
      self.logger.error("DDayStore skipped \(skippedCount) unreadable folder rows")
    }
    return folders
  }

  /// 읽을 수 있는 폴더의 id 집합 (`fetchAll` 의 folderID 정규화).
  static func readableFolderIDs(
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> Set<UUID> {
    try Set(self.readableFolders(in: context, operation: operation).map(\.id))
  }

  /// `draft.folderID` 가 없는 폴더를 가리키면 nil(미분류)로 바꾼 draft. 행 존재(`fetchCount`)로 확인한다.
  static func normalizingFolder(
    _ draft: DDayDraft,
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> DDayDraft {
    guard let folderID = draft.folderID else { return draft }
    var descriptor = FetchDescriptor<DDayFolderRecord>(predicate: #Predicate { $0.id == folderID })
    descriptor.fetchLimit = 1
    let count: Int
    do {
      count = try context.fetchCount(descriptor)
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
    guard count == 0 else { return draft }
    var normalized = draft
    normalized.folderID = nil
    return normalized
  }
}
