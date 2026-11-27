import Core
import SwiftUI
import UIKit

/// 편집 화면의 3:2 사진 미리보기. 썸네일 JPEG 은 `byPreparingForDisplay()` 로 메인 밖에서 디코딩해 View 일시 상태에 둔다
/// (PRODUCT §2 썸네일 표시). `.task(id: Data)` 라 Data 가 바뀔 때와 다시 나타날 때(자르기 화면에서 돌아올 때 등) 다시
/// 디코딩한다 (캐시 없음). 사진이 없거나 디코딩에 실패하면 사진 아이콘 자리 표시.
/// Home 의 `CardThumbnailImage` 와 같은 방식이다 (Feature 끼리 공유할 수 없어 따로 둔다).
struct EditorThumbnailImage: View {
  let data: Data?
  @State private var image: UIImage?

  var body: some View {
    Color(.secondarySystemFill)
      .aspectRatio(PhotoCropGeometry.aspectRatio, contentMode: .fit)
      .overlay {
        if let image = self.image {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .accessibilityLabel(Text(DDayEditorText.photoPreview))
        } else {
          Image(systemName: "photo")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      .clipped()
      .task(id: self.data) {
        guard let data = self.data else {
          self.image = nil
          return
        }
        let image = await UIImage(data: data)?.byPreparingForDisplay()
        // 사라지거나 사진이 바뀌어 취소됐으면 쓰지 않는다 (취소로 온 nil 로 아이콘이 깜빡이지 않게).
        guard !Task.isCancelled else { return }
        self.image = image
      }
  }
}
