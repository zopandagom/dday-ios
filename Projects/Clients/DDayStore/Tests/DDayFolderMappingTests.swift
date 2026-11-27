import Core
import DDayStoreInterface
import Foundation
import Testing
@testable import DDayStoreImpl

struct DDayFolderMappingTests {
  private static let createdAt = Date(timeIntervalSince1970: 1_700_000_000.25)

  private static func fields(
    systemKey: String? = "birthday",
    customName: String? = nil,
    colorKey: String = "peach",
    iconKey: String = "cake"
  ) -> DDayFolderRecordFields {
    DDayFolderRecordFields(
      id: Sample.id(1),
      systemKey: systemKey,
      customName: customName,
      colorKey: colorKey,
      iconKey: iconKey,
      sortOrder: 0,
      createdAt: self.createdAt,
      updatedAt: self.createdAt
    )
  }

  @Test("기본 폴더의 행 값을 다시 읽으면 그 기본 폴더다", arguments: DefaultFolder.allCases)
  func defaultFolderRoundTrip(folder: DefaultFolder) {
    let fields = DDayFolderMapping.fields(for: folder, id: Sample.id(5), createdAt: Self.createdAt)

    #expect(fields.customName == nil)
    #expect(fields.sortOrder == folder.order)
    #expect(fields.createdAt == fields.updatedAt)
    #expect(
      DDayFolderMapping.folder(from: fields)
        == DDayFolder(id: Sample.id(5), name: .system(folder), color: folder.color, icon: folder.icon)
    )
  }

  @Test("모든 색의 쓰기 문자열이 같은 색으로 읽힌다", arguments: FolderColor.allCases)
  func colorRoundTrip(color: FolderColor) {
    let fields = Self.fields(colorKey: DDayFolderMapping.string(for: color))
    #expect(DDayFolderMapping.folder(from: fields)?.color == color)
  }

  @Test("모든 아이콘의 쓰기 문자열이 같은 아이콘으로 읽힌다", arguments: FolderIcon.allCases)
  func iconRoundTrip(icon: FolderIcon) {
    let fields = Self.fields(iconKey: DDayFolderMapping.string(for: icon))
    #expect(DDayFolderMapping.folder(from: fields)?.icon == icon)
  }

  @Test("저장 문자열이 고정되어 있다")
  func storedStrings() {
    #expect(DefaultFolder.allCases.map(DDayFolderMapping.string(for:)) == ["birthday", "family", "couple", "other"])
    #expect(
      FolderColor.allCases.map(DDayFolderMapping.string(for:))
        == ["blushPink", "lavender", "peach", "mint", "butter"]
    )
    #expect(FolderIcon.allCases.map(DDayFolderMapping.string(for:)) == [
      "cake", "house", "heart", "star", "gift", "airplane",
      "graduationCap", "book", "musicNote", "pawprint", "briefcase", "sparkles",
    ])
  }

  @Test("customName 이 있으면 systemKey 와 상관없이 그 이름이다")
  func customNameWins() {
    #expect(DDayFolderMapping.folder(from: Self.fields(customName: "우리 집"))?.name == .custom("우리 집"))
    #expect(DDayFolderMapping.folder(from: Self.fields(systemKey: nil, customName: "여행"))?.name == .custom("여행"))
    #expect(DDayFolderMapping.folder(from: Self.fields(systemKey: "unknown", customName: "시험"))?.name == .custom("시험"))
  }

  @Test("읽을 수 없는 값이면 nil: 이름 없음·모르는 systemKey·모르는 colorKey·모르는 iconKey")
  func unreadable() {
    #expect(DDayFolderMapping.folder(from: Self.fields(systemKey: nil, customName: nil)) == nil)
    #expect(DDayFolderMapping.folder(from: Self.fields(systemKey: "unknown")) == nil)
    #expect(DDayFolderMapping.folder(from: Self.fields(colorKey: "red")) == nil)
    #expect(DDayFolderMapping.folder(from: Self.fields(iconKey: "rocket")) == nil)
  }
}
