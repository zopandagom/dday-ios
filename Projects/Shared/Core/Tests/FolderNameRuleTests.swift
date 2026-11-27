import Core
import Testing

struct FolderNameRuleTests {
  @Test(
    "앞뒤 공백·줄바꿈·NBSP·전각 공백을 정리한다",
    arguments: [
      ("  여행 ", "여행"),
      ("\n여행\t\n", "여행"),
      ("\u{00A0}여행\u{00A0}", "여행"),
      ("\u{3000}여행\u{3000}", "여행"),
    ]
  )
  func normalizesEdges(text: String, expected: String) {
    #expect(FolderNameRule.normalized(text) == expected)
    #expect(FolderNameRule.validate(text) == .valid(expected))
  }

  @Test("빈 문자열과 공백만 있는 이름은 empty", arguments: ["", "   ", "\n\t", "\u{3000}"])
  func emptyNames(text: String) {
    #expect(FolderNameRule.validate(text) == .empty)
  }

  @Test("정확히 20자는 받고 21자는 tooLong")
  func lengthLimit() {
    let twenty = String(repeating: "가", count: 20)
    #expect(FolderNameRule.maxLength == 20)
    #expect(FolderNameRule.validate(twenty) == .valid(twenty))
    #expect(FolderNameRule.validate(twenty + "가") == .tooLong)
  }

  @Test("앞뒤 공백을 포함해 22자여도 정리하면 20자라 받는다")
  func lengthCountsAfterNormalizing() {
    let twenty = String(repeating: "a", count: 20)
    #expect(FolderNameRule.validate(" \(twenty) ") == .valid(twenty))
  }

  @Test("ZWJ 이모지와 결합 문자는 한 글자로 센다")
  func countsGraphemes() {
    #expect(FolderNameRule.length("👨‍👩‍👧") == 1)
    #expect(FolderNameRule.length("e\u{301}") == 1)
    let twentyEmoji = String(repeating: "👨‍👩‍👧", count: 20)
    #expect(FolderNameRule.validate(twentyEmoji) == .valid(twentyEmoji))
  }

  @Test("가운데 공백·줄바꿈은 그대로 둔다")
  func keepsInnerWhitespace() {
    #expect(FolderNameRule.validate(" 우리  가족\n사진 ") == .valid("우리  가족\n사진"))
  }

  @Test("length 는 정리한 뒤 글자 수")
  func lengthAfterNormalizing() {
    #expect(FolderNameRule.length("  여행 \n") == 2)
    #expect(FolderNameRule.length("   ") == 0)
  }
}
