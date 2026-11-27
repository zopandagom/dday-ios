import Core
import Foundation

/// 저장된 폴더. 저장소가 만든다 (기본 폴더는 저장소를 처음 열 때, 나머지는 `addFolder`).
/// 순서 값·생성 시각은 노출하지 않는다: `DDayStoreClient.fetchFolders()` 가 순서대로 돌려준다.
public struct DDayFolder: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let name: FolderName
  public let color: FolderColor
  public let icon: FolderIcon

  public init(id: UUID, name: FolderName, color: FolderColor, icon: FolderIcon) {
    self.id = id
    self.name = name
    self.color = color
    self.icon = icon
  }
}
