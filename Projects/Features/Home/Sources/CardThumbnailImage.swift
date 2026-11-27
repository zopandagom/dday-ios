import DDayStoreInterface
import SwiftUI
import UIKit

/// 카드 배경의 사진 썸네일. 썸네일 JPEG 은 `byPreparingForDisplay()` 로 메인 밖에서 디코딩해 View 일시 상태에 둔다
/// (PRODUCT §2 썸네일 표시). `.task(id: 사진 id)` 라 사진 id 가 바뀔 때와 카드가 다시 나타날 때 다시 디코딩한다 (캐시 없음).
/// 디코딩 전에는 중립 색(사진 카드가 기본 배경으로 깜빡이지 않게), 실패하면 기본 배경. 편집 화면의 `EditorThumbnailImage` 와 같은 방식이다 (Feature 끼리 공유할 수 없다).
struct CardThumbnailImage: View {
  private enum Decoded {
    case pending
    case image(UIImage)
    case failed
  }

  let photo: DDayPhoto
  @State private var decoded = Decoded.pending

  var body: some View {
    Group {
      switch self.decoded {
      case .pending:
        Color(.secondarySystemFill)
      case let .image(image):
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      case .failed:
        DefaultCardBackground()
      }
    }
    .task(id: self.photo.id) {
      let image = await UIImage(data: self.photo.thumbnail)?.byPreparingForDisplay()
      // 사라지거나 사진이 바뀌어 취소됐으면 쓰지 않는다 (취소로 온 nil 을 디코딩 실패로 보이지 않게).
      guard !Task.isCancelled else { return }
      self.decoded = image.map { .image($0) } ?? .failed
    }
  }
}

/// 사진이 없는 카드의 기본 배경 (`HomeAsset.defaultCardBackground`).
struct DefaultCardBackground: View {
  var body: some View {
    Image(HomeAsset.defaultCardBackground, bundle: .module)
      .resizable()
      .scaledToFill()
  }
}
