import Core
import DDayStoreInterface
import SwiftUI
import UIKit

/// 상세 머리의 사진 (폭 가득 3:2). 사진이 없으면 폴더 색 기본 배경(미분류는 기본 배경), 있으면 썸네일을 늘 아래에 깔고 압축본을 읽어 디코딩했으면 그 위에 덮는다
/// (압축본 디코딩 전·실패에 깜빡이지 않게). 읽는 중·nil·실패면 썸네일만 보인다.
struct DetailPhotoView: View {
  let photo: DDayPhoto?
  let largePhoto: DDayDetailModel.LargePhoto?
  /// 사진이 없거나 썸네일 디코딩에 실패했을 때의 배경 색. nil 이면 미분류 기본 배경.
  let folderColor: FolderColor?

  var body: some View {
    Color.clear
      .aspectRatio(PhotoCropGeometry.aspectRatio, contentMode: .fit)
      .background {
        self.content
      }
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var content: some View {
    if let photo = self.photo {
      ZStack {
        CardThumbnailImage(photo: photo, folderColor: self.folderColor)
        if case let .loaded(data) = self.largePhoto {
          DetailLargePhotoImage(photoID: photo.id, data: data)
        }
      }
    } else {
      DefaultCardBackground(folderColor: self.folderColor)
    }
  }
}

/// 상세 압축본. JPEG 을 `byPreparingForDisplay()` 로 메인 밖에서 디코딩해 View 일시 상태에 둔다 (`CardThumbnailImage` 와 같은 방식,
/// 캐시 없음). `largePhoto` 는 늘 지금 사진의 상태라 `.task(id: 사진 id)` 로 다시 디코딩한다. 디코딩 전·실패는 투명(아래 썸네일이 보인다).
struct DetailLargePhotoImage: View {
  let photoID: UUID
  let data: Data
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image = self.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Color.clear
      }
    }
    .task(id: self.photoID) {
      let image = await UIImage(data: self.data)?.byPreparingForDisplay()
      // 사라지거나 사진이 바뀌어 취소됐으면 쓰지 않는다.
      guard !Task.isCancelled else { return }
      self.image = image
    }
  }
}
