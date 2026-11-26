import SwiftUI

/// 디데이 카드 하나: 제목, 날짜, 카운트.
public struct DDayCardView: View {
  let item: HomeItem
  @Environment(\.locale) private var locale

  public init(item: HomeItem) {
    self.item = item
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        // 사용자 입력 그대로 (문구 키로 쓰지 않는다)
        Text(verbatim: self.item.dDay.title)
          .font(.headline)
        Text(verbatim: HomeText.dateText(self.item.status.date, locale: self.locale))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Text(HomeText.count(self.item.status.label))
        .font(.title2.bold())
        .monospacedDigit()
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}
