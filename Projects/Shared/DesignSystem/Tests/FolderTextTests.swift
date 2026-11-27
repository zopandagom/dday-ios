import Core
import Foundation
import Testing
@testable import DesignSystem

struct FolderTextTests {
  static let korean = Locale(identifier: "ko_KR")
  static let english = Locale(identifier: "en_US")

  func text(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  @Test(
    "기본 폴더 이름",
    arguments: [
      (DefaultFolder.birthday, "생일", "Birthday"),
      (.family, "가족", "Family"),
      (.couple, "연인", "Couple"),
      (.other, "기타", "Other"),
    ]
  )
  func defaultName(folder: DefaultFolder, korean: String, english: String) {
    #expect(self.text(FolderText.defaultName(folder), Self.korean) == korean)
    #expect(self.text(FolderText.defaultName(folder), Self.english) == english)
  }

  @Test("미분류")
  func unfiled() {
    #expect(self.text(FolderText.unfiled, Self.korean) == "미분류")
    #expect(self.text(FolderText.unfiled, Self.english) == "Unfiled")
  }
}
