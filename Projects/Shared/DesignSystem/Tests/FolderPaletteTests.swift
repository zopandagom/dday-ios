import Core
import Testing
@testable import DesignSystem

struct FolderPaletteTests {
  /// PRODUCT §2 "디자인 팔레트" 값 (라이트, 다크).
  static let expected: [FolderColor: (light: UInt32, dark: UInt32)] = [
    .blushPink: (0xFF8FB1, 0xFF8FB1),
    .lavender: (0xC9B6FF, 0xA996F0),
    .peach: (0xFFC6A8, 0xF0A989),
    .mint: (0xA8E6CF, 0x7FCFB2),
    .butter: (0xFFE8A3, 0xE8CF7E),
  ]

  @Test("폴더 색 값이 PRODUCT §2 팔레트와 같다", arguments: FolderColor.allCases)
  func hex(color: FolderColor) throws {
    let expected = try #require(Self.expected[color])
    let actual = FolderPalette.hex(color)
    #expect(actual.light == expected.light)
    #expect(actual.dark == expected.dark)
  }
}
