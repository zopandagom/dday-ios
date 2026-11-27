import Core
import SwiftUI

/// 폴더 한 줄: 폴더 색 원 안의 아이콘 + 이름. 편집 화면 폴더 선택 행·상세의 폴더 행이 쓴다. 상태 없음.
public struct FolderLabel: View {
  private let title: Text
  private let fill: Color
  private let image: Image

  public init(name: FolderName, color: FolderColor, icon: FolderIcon) {
    self.init(title: name.text, fill: color.color, image: icon.image)
  }

  private init(title: Text, fill: Color, image: Image) {
    self.title = title
    self.fill = fill
    self.image = image
  }

  /// 미분류: 회색 원 안의 `tray` 아이콘 + "미분류".
  public static var unfiled: some View {
    FolderLabel(title: Text(FolderText.unfiled), fill: Color(.systemGray4), image: Image(systemName: "tray"))
  }

  public var body: some View {
    Label {
      self.title
    } icon: {
      self.image
        .font(.caption)
        .foregroundStyle(.primary)
        .frame(width: 26, height: 26)
        .background(Circle().fill(self.fill))
    }
  }
}
