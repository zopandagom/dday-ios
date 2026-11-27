import Core
import SwiftUI

/// 폴더 아이콘 그림. 지금은 임시 SF Symbol 이고, 6단계에 같은 키(`FolderIcon`)로 에셋으로 바꾼다.
public extension FolderIcon {
  /// SF Symbol 이름 (임시).
  var systemImageName: String {
    switch self {
    case .cake: "birthday.cake.fill"
    case .house: "house.fill"
    case .heart: "heart.fill"
    case .star: "star.fill"
    case .gift: "gift.fill"
    case .airplane: "airplane"
    case .graduationCap: "graduationcap.fill"
    case .book: "book.fill"
    case .musicNote: "music.note"
    case .pawprint: "pawprint.fill"
    case .briefcase: "briefcase.fill"
    case .sparkles: "sparkles"
    }
  }

  var image: Image {
    Image(systemName: self.systemImageName)
  }
}
