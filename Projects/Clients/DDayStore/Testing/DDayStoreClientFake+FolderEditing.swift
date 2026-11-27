import Core
import DDayStoreInterface
import Foundation
import Synchronization

/// 폴더 쓰기 4개 (규칙·호출 시점은 `DDayStoreClientFake` 문서 주석).
public extension DDayStoreClientFake {
  func addFolder(_ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDayFolder in
      let injected = try Self.takeErrorBeforeSave(&locked)
      let name = try Self.validatedName(draft.name, systemKey: nil)
      let id = self.makeID()
      guard !locked.folders.contains(where: { $0.id == id }) else { throw DDayStoreError.alreadyExists }
      // 값은 쓰지 않지만 Impl 과 같은 때에 부른다.
      _ = self.now()
      if let injected {
        throw injected
      }
      let folder = DDayFolder(id: id, name: name, color: draft.color, icon: draft.icon)
      locked.folders.append(folder)
      return folder
    }
  }

  func updateFolder(id: UUID, _ draft: DDayFolderDraft) async throws(DDayStoreError) -> DDayFolder {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDayFolder in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard let index = locked.folders.firstIndex(where: { $0.id == id }) else { throw DDayStoreError.notFound }
      let name = try Self.validatedName(draft.name, systemKey: locked.systemKeys[id])
      _ = self.now()
      if let injected {
        throw injected
      }
      let folder = DDayFolder(id: id, name: name, color: draft.color, icon: draft.icon)
      locked.folders[index] = folder
      return folder
    }
  }

  func moveFolders(_ orderedIDs: [UUID]) async throws(DDayStoreError) -> [DDayFolder] {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> [DDayFolder] in
      let injected = try Self.takeErrorBeforeSave(&locked)
      let byID = Dictionary(locked.folders.map { ($0.id, $0) }) { first, _ in first }
      // 겹침은 개수 비교로 걸린다.
      guard orderedIDs.count == byID.count, Set(orderedIDs) == Set(byID.keys) else {
        throw DDayStoreError.notFound
      }
      if let injected {
        throw injected
      }
      let folders = orderedIDs.compactMap { byID[$0] }
      locked.folders = folders
      return folders
    }
  }

  func deleteFolder(id: UUID, dDays deletion: FolderDeletion) async throws(DDayStoreError) -> [UUID] {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> [UUID] in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard locked.folders.contains(where: { $0.id == id }) else { throw DDayStoreError.notFound }
      if let injected {
        throw injected
      }
      let contained = Self.sorted(locked.dDays.filter { $0.value.folderID == id })
      var deletedIDs: [UUID] = []
      for dDay in contained {
        switch deletion {
        case .moveToUnfiled:
          // folderID 만 nil 로, 수정 시각 등은 그대로 (Impl 과 같다).
          locked.dDays[dDay.id] = Self.withoutFolder(dDay)
        case .delete:
          locked.dDays[dDay.id] = nil
          locked.images[dDay.id] = nil
          deletedIDs.append(dDay.id)
        }
      }
      locked.folders.removeAll { $0.id == id }
      locked.systemKeys[id] = nil
      return deletedIDs
    }
  }

  /// `.custom` 은 `FolderNameRule` 로 정리한 이름, `.system(키)` 는 그 폴더의 기본 폴더 키가 같을 때만 (Impl 과 같은 규칙).
  private static func validatedName(
    _ name: FolderName,
    systemKey: DefaultFolder?
  ) throws(DDayStoreError) -> FolderName {
    switch name {
    case let .custom(text):
      guard case let .valid(normalized) = FolderNameRule.validate(text) else {
        throw DDayStoreError.invalidFolderName
      }
      return .custom(normalized)
    case let .system(key):
      guard key == systemKey else { throw DDayStoreError.invalidFolderName }
      return .system(key)
    }
  }
}
