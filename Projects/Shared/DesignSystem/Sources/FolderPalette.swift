import Core
import SwiftUI
import UIKit

/// 폴더 색 값 (PRODUCT §2 팔레트). 라이트·다크 두 벌의 0xRRGGBB.
/// Blush Pink 는 PRODUCT 에 한 값뿐이라 라이트·다크가 같다.
enum FolderPalette {
  static func hex(_ color: FolderColor) -> (light: UInt32, dark: UInt32) {
    switch color {
    case .blushPink: (light: 0xFF8FB1, dark: 0xFF8FB1)
    case .lavender: (light: 0xC9B6FF, dark: 0xA996F0)
    case .peach: (light: 0xFFC6A8, dark: 0xF0A989)
    case .mint: (light: 0xA8E6CF, dark: 0x7FCFB2)
    case .butter: (light: 0xFFE8A3, dark: 0xE8CF7E)
    }
  }

  static func uiColor(hex: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

public extension FolderColor {
  /// 화면에 쓰는 색. 다크 모드에서는 다크 값으로 바뀐다.
  var color: Color {
    let (light, dark) = FolderPalette.hex(self)
    let lightColor = FolderPalette.uiColor(hex: light)
    let darkColor = FolderPalette.uiColor(hex: dark)
    return Color(UIColor { traits in
      traits.userInterfaceStyle == .dark ? darkColor : lightColor
    })
  }
}
