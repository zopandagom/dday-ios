/// 기본 폴더 (systemKey). 저장소를 처음 열 때 이 순서로 만든다. 이름은 DesignSystem 이 앱 언어로 보인다.
/// rawValue(= case 이름)는 `FolderColor` 와 같은 이유로 `DefaultFolderTests` 가 고정한다.
public enum DefaultFolder: String, CaseIterable, Hashable, Sendable {
  case birthday
  case family
  case couple
  case other

  /// 기본 색.
  public var color: FolderColor {
    switch self {
    case .birthday: .peach
    case .family: .mint
    case .couple: .blushPink
    case .other: .lavender
    }
  }

  /// 기본 아이콘. 네 폴더가 서로 다르다.
  public var icon: FolderIcon {
    switch self {
    case .birthday: .cake
    case .family: .house
    case .couple: .heart
    case .other: .star
    }
  }

  /// 처음 표시 순서 (`allCases` 의 index: 0, 1, 2, 3).
  public var order: Int {
    switch self {
    case .birthday: 0
    case .family: 1
    case .couple: 2
    case .other: 3
    }
  }
}
