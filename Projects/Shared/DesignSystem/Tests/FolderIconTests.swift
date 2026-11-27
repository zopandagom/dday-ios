import Core
import Testing
import UIKit
@testable import DesignSystem

struct FolderIconTests {
  @Test("아이콘 심볼 이름은 서로 다르다")
  func distinctNames() {
    #expect(Set(FolderIcon.allCases.map(\.systemImageName)).count == FolderIcon.allCases.count)
  }

  @Test("아이콘 심볼이 시스템에 있다", arguments: FolderIcon.allCases)
  func symbolExists(icon: FolderIcon) {
    #expect(UIImage(systemName: icon.systemImageName) != nil)
  }
}
