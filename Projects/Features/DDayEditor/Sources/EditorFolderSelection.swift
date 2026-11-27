import DDayStoreInterface
import Foundation

/// 편집 화면의 폴더 선택. `DDayEditorModel` 이 `folderSelection` 으로 하나 갖는다.
///
/// - 고를 수 있는 폴더는 App 이 열 때 넘긴 목록(홈이 불러온 값)이고 바뀌지 않는다. 편집 화면은 저장소에서 폴더를 읽지 않는다.
///   목록이 비면(홈 불러오기 전·실패) 미분류로만 저장한다.
/// - `folderID` 는 늘 nil(미분류)이거나 `folders` 안의 id 다. 처음 폴더(추가: 홈에서 고른 칩, 수정: 저장된 폴더)가
///   목록에 없으면 미분류로 연다. Model 은 처음 값(`initialDraft`)도 같은 값으로 맞춰 말없이 바뀐 것으로 보지 않는다
///   (저장소도 없는 폴더는 미분류로 읽고 쓴다).
/// - 편집 phase 는 보지 않는다 (`DDayEditorModel.folderChanged(_:)` 가 본다).
public struct EditorFolderSelection: Equatable, Sendable {
  public private(set) var folders: [DDayFolder]
  public private(set) var folderID: UUID?

  /// - Parameters:
  ///   - defaultFolderID: 추가 모드의 처음 폴더 (홈에서 고른 칩). 수정 모드는 쓰지 않는다 (저장된 폴더).
  init(mode: DDayEditorMode, folders: [DDayFolder], defaultFolderID: UUID?) {
    let start: UUID? = switch mode {
    case .add: defaultFolderID
    case let .edit(dDay): dDay.folderID
    }
    self.folders = folders
    self.folderID = start.flatMap { id in folders.contains { $0.id == id } ? id : nil }
  }

  /// nil(미분류)이거나 `folders` 에 있는 id 만 받고 그 밖은 무시한다.
  mutating func select(_ folderID: UUID?) {
    if let folderID, !self.folders.contains(where: { $0.id == folderID }) {
      return
    }
    self.folderID = folderID
  }
}
