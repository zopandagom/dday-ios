import Foundation

/// 폴더 이름 규칙. 폴더 폼(저장 버튼·안내)과 저장소(`addFolder`·`updateFolder` 검증)가 함께 쓴다.
/// 앞뒤 공백·줄바꿈(`whitespacesAndNewlines`)을 정리한 뒤 1~20자(문자 = `Character`, grapheme 단위)면 받는다.
/// 가운데 공백·줄바꿈은 그대로 둔다. 이름 중복은 허용한다.
public enum FolderNameRule {
  /// 최대 글자 수 (정리한 뒤, grapheme 단위).
  public static let maxLength = 20

  public enum Validation: Equatable, Sendable {
    /// 받는 이름. 값은 정리한 이름 (저장할 값).
    case valid(String)
    /// 정리하면 빈 이름.
    case empty
    /// 정리한 뒤 `maxLength` 보다 길다.
    case tooLong
  }

  /// 앞뒤 공백·줄바꿈을 뺀 값.
  public static func normalized(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 정리한 이름의 글자 수 (폼의 "n/20" 표시).
  public static func length(_ text: String) -> Int {
    self.normalized(text).count
  }

  public static func validate(_ text: String) -> Validation {
    let name = self.normalized(text)
    if name.isEmpty {
      return .empty
    }
    if name.count > self.maxLength {
      return .tooLong
    }
    return .valid(name)
  }
}
