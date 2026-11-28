import Core
import Foundation
import Testing
@testable import FolderManagerFeature

/// 키를 실행 중에 만드는 문구(`FolderManagerText.iconName(_:)`)가 카탈로그에 ko·en 으로 모두 있는지 본다.
/// 키가 없으면 `String(localized:)` 가 키 문자열을 그대로 돌려준다.
struct FolderManagerTextTests {
  static let korean = Locale(identifier: "ko_KR")
  static let english = Locale(identifier: "en_US")

  func text(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  @Test("모든 아이콘에 ko·en 이름이 있다", arguments: FolderIcon.allCases)
  func iconNameIsLocalized(icon: FolderIcon) {
    let key = "folderForm.icon." + icon.rawValue
    let korean = self.text(FolderManagerText.iconName(icon), Self.korean)
    let english = self.text(FolderManagerText.iconName(icon), Self.english)
    #expect(!korean.isEmpty && korean != key)
    #expect(!english.isEmpty && english != key)
    #expect(korean != english)
  }

  @Test("아이콘 이름은 서로 겹치지 않는다")
  func iconNamesAreDistinct() {
    for locale in [Self.korean, Self.english] {
      let names = FolderIcon.allCases.map { self.text(FolderManagerText.iconName($0), locale) }
      #expect(Set(names).count == names.count)
    }
  }
}
