import Core
import DDayStoreInterface
import Foundation

/// `DDayFolderRecord` 의 필드 값 사본. 순수 변환과 테스트가 컨테이너 없이 쓰도록 분리한다.
struct DDayFolderRecordFields: Hashable, Sendable {
  var id: UUID
  var systemKey: String?
  var customName: String?
  var colorKey: String
  var iconKey: String
  var sortOrder: Int
  var createdAt: Date
  var updatedAt: Date
}

/// 폴더 저장값 ↔ Interface 값 변환. 원칙은 `DDayRecordMapping` 과 같다: 저장 문자열은 여기 리터럴로 적고(Core 의
/// rawValue 를 쓰지 않는다), 쓰기 `switch` 는 `default` 없이, 쓰기가 만들 수 있는 값은 모두 읽는다 (읽기는 쓰기
/// 문자열을 거꾸로 찾아 이를 구조로 보장한다).
///
/// - 이름: `customName` 이 있으면 `.custom`(`systemKey` 는 보지 않는다), 없으면 `systemKey` 의 기본 이름(`.system`).
/// - 읽기 실패(nil): 모르는 `colorKey`·`iconKey`, `customName` 이 nil 인데 `systemKey` 가 nil 이거나 모르는 값.
enum DDayFolderMapping {
  /// 기본 폴더 하나의 행 값 (customName nil, sortOrder = `DefaultFolder.order`, createdAt == updatedAt).
  static func fields(for folder: DefaultFolder, id: UUID, createdAt: Date) -> DDayFolderRecordFields {
    DDayFolderRecordFields(
      id: id,
      systemKey: self.string(for: folder),
      customName: nil,
      colorKey: self.string(for: folder.color),
      iconKey: self.string(for: folder.icon),
      sortOrder: folder.order,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  /// 읽을 수 없는 값이면 nil.
  static func folder(from fields: DDayFolderRecordFields) -> DDayFolder? {
    guard let color = self.color(from: fields.colorKey),
          let icon = self.icon(from: fields.iconKey)
    else {
      return nil
    }
    let name: FolderName
    if let customName = fields.customName {
      name = .custom(customName)
    } else if let systemKey = fields.systemKey, let folder = self.defaultFolder(from: systemKey) {
      name = .system(folder)
    } else {
      return nil
    }
    return DDayFolder(id: fields.id, name: name, color: color, icon: icon)
  }

  // MARK: - 저장 문자열 (V1, 출시 뒤 바꾸지 않는다)

  static func string(for folder: DefaultFolder) -> String {
    switch folder {
    case .birthday: "birthday"
    case .family: "family"
    case .couple: "couple"
    case .other: "other"
    }
  }

  static func string(for color: FolderColor) -> String {
    switch color {
    case .blushPink: "blushPink"
    case .lavender: "lavender"
    case .peach: "peach"
    case .mint: "mint"
    case .butter: "butter"
    }
  }

  /// 예외: 아이콘은 case 가 12개라 쓰기 switch 가 cyclomatic_complexity 에 걸려 Core `FolderIcon.rawValue` 를 저장
  /// 문자열로 쓴다 (`DefaultFolderTests`·`DDayFolderMappingTests` 가 목록을 고정한다, 출시 뒤 바꾸지 않는다).
  static func string(for icon: FolderIcon) -> String {
    icon.rawValue
  }

  // 읽기는 쓰기 문자열을 거꾸로 찾는다: 쓰기가 만드는 값은 모두 읽고, 그 밖의 문자열은 nil 이다.

  private static func defaultFolder(from string: String) -> DefaultFolder? {
    DefaultFolder.allCases.first { self.string(for: $0) == string }
  }

  private static func color(from string: String) -> FolderColor? {
    FolderColor.allCases.first { self.string(for: $0) == string }
  }

  private static func icon(from string: String) -> FolderIcon? {
    FolderIcon(rawValue: string)
  }
}
