import Core
import Foundation

/// 폴더 문구. 모두 이 모듈의 `Localizable.xcstrings`(ko·en)에서 온다. 키는 `folder.` 으로 시작한다.
public enum FolderText {
  /// 기본 폴더의 이름 (사용자가 이름을 정하지 않은 기본 폴더).
  public static func defaultName(_ folder: DefaultFolder) -> LocalizedStringResource {
    switch folder {
    case .birthday: self.resource("folder.default.birthday")
    case .family: self.resource("folder.default.family")
    case .couple: self.resource("folder.default.couple")
    case .other: self.resource("folder.default.other")
    }
  }

  /// 폴더에 넣지 않은 디데이 (홈 칩·편집 선택·상세).
  public static var unfiled: LocalizedStringResource { self.resource("folder.unfiled") }

  private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
  }
}
