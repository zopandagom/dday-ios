import Core
import SwiftUI

public extension FolderName {
  /// 화면에 보이는 이름. 기본 이름은 앱 언어로, 사용자가 정한 이름은 그대로 (번역 키로 보지 않는다).
  var text: Text {
    switch self {
    case let .system(folder): Text(FolderText.defaultName(folder))
    case let .custom(name): Text(verbatim: name)
    }
  }
}
