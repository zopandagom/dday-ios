import Core
import SwiftUI

/// 디데이 카드 하나 (3:2): 배경(사진 썸네일 또는 기본 배경) 위에 제목, 날짜, 카운트.
public struct DDayCardView: View {
  let item: HomeItem
  @Environment(\.locale) private var locale

  public init(item: HomeItem) {
    self.item = item
  }

  public var body: some View {
    Color.clear
      .aspectRatio(PhotoCropGeometry.aspectRatio, contentMode: .fit)
      .background {
        self.background
          .accessibilityHidden(true)
      }
      .overlay(alignment: .bottom) {
        self.labels
      }
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .contentShape(RoundedRectangle(cornerRadius: 16))
      .padding(.vertical, 4)
      .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var background: some View {
    if let photo = self.item.dDay.photo {
      CardThumbnailImage(photo: photo)
    } else {
      DefaultCardBackground()
    }
  }

  /// 글자 가독성을 위해 아래쪽을 어둡게 하고 흰 글자로 쓴다.
  private var labels: some View {
    HStack(alignment: .bottom, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        // 사용자 입력 그대로 (문구 키로 쓰지 않는다)
        Text(verbatim: self.item.dDay.title)
          .font(.headline)
          .lineLimit(2)
        Text(verbatim: HomeText.dateText(self.item.status.date, locale: self.locale))
          .font(.subheadline)
          .opacity(0.85)
      }
      Spacer(minLength: 8)
      Text(HomeText.count(self.item.status.label))
        .font(.title2.bold())
        .monospacedDigit()
    }
    .foregroundStyle(.white)
    .padding(16)
    .frame(maxWidth: .infinity)
    .background {
      LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
    }
  }
}
