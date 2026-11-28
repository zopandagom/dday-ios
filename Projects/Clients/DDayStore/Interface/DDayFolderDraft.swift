import Core

/// 폴더 추가·수정 입력.
/// - `name`: `.custom(이름)` 은 저장소가 `FolderNameRule` 로 검증·정리해 저장한다 (원문 그대로 저장하지 않는다).
///   `.system(key)` 는 "기본 이름 그대로"라는 뜻이고, 수정에서 그 행의 기본 폴더 키가 `key` 일 때만 받는다 (추가에서는 받지 않는다).
public struct DDayFolderDraft: Hashable, Sendable {
  public var name: FolderName
  public var color: FolderColor
  public var icon: FolderIcon

  public init(name: FolderName, color: FolderColor, icon: FolderIcon) {
    self.name = name
    self.color = color
    self.icon = icon
  }
}

/// 폴더를 지울 때 안의 디데이를 어떻게 할지.
public enum FolderDeletion: Hashable, Sendable {
  /// 디데이는 남기고 미분류(folderID nil)로 옮긴다.
  case moveToUnfiled
  /// 디데이도 사진(썸네일·압축본)과 함께 지운다.
  case delete
}
