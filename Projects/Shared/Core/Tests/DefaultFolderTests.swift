import Core
import Testing

struct DefaultFolderTests {
  @Test(
    "기본 폴더의 색·아이콘·순서",
    arguments: [
      (DefaultFolder.birthday, FolderColor.peach, FolderIcon.cake, 0),
      (.family, .mint, .house, 1),
      (.couple, .blushPink, .heart, 2),
      (.other, .lavender, .star, 3),
    ]
  )
  func values(folder: DefaultFolder, color: FolderColor, icon: FolderIcon, order: Int) {
    #expect(folder.color == color)
    #expect(folder.icon == icon)
    #expect(folder.order == order)
  }

  @Test("순서는 allCases 의 index 이고, 아이콘은 서로 다르다")
  func orderAndDistinctIcons() {
    #expect(DefaultFolder.allCases.map(\.order) == Array(DefaultFolder.allCases.indices))
    #expect(Set(DefaultFolder.allCases.map(\.icon)).count == DefaultFolder.allCases.count)
  }

  @Test("rawValue 목록이 고정되어 있다")
  func rawValues() {
    #expect(FolderColor.allCases.map(\.rawValue) == ["blushPink", "lavender", "peach", "mint", "butter"])
    #expect(FolderIcon.allCases.map(\.rawValue) == [
      "cake", "house", "heart", "star", "gift", "airplane",
      "graduationCap", "book", "musicNote", "pawprint", "briefcase", "sparkles",
    ])
    #expect(DefaultFolder.allCases.map(\.rawValue) == ["birthday", "family", "couple", "other"])
  }

  @Test("아이콘은 12개다")
  func iconCount() {
    #expect(FolderIcon.allCases.count == 12)
  }
}
