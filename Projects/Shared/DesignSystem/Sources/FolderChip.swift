import Core
import SwiftUI

/// 홈 필터 칩 (캡슐 버튼). 선택되면 폴더 색 배경(색이 없는 칩은 Blush Pink), 아니면 회색 배경. 상태 없음.
public struct FolderChip: View {
  private let title: Text
  private let color: FolderColor?
  private let icon: FolderIcon?
  private let isSelected: Bool
  private let action: () -> Void

  /// - Parameters:
  ///   - color: 폴더 색. 전체·미분류 칩은 nil.
  ///   - icon: 폴더 아이콘. 없으면 이름만 보인다.
  public init(
    title: Text,
    color: FolderColor?,
    icon: FolderIcon?,
    isSelected: Bool,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.color = color
    self.icon = icon
    self.isSelected = isSelected
    self.action = action
  }

  public var body: some View {
    Button(action: self.action) {
      HStack(spacing: 4) {
        if let icon = self.icon {
          icon.image
            .font(.caption)
        }
        self.title
          .font(.subheadline.weight(self.isSelected ? .semibold : .regular))
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Capsule().fill(self.background))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(self.isSelected ? .isSelected : [])
  }

  private var background: Color {
    guard self.isSelected else { return Color(.secondarySystemFill) }
    return (self.color ?? .blushPink).color
  }
}
