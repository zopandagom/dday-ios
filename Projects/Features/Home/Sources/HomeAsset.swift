import Core

/// Home 의 에셋 이름 (`Sources/Assets.xcassets`). 이름은 여기 한 곳에만 쓴다.
enum HomeAsset {
  /// 미분류(사진 없음)의 기본 배경. 자리 표시, 6단계에 같은 이름으로 교체.
  static let defaultCardBackground = "DefaultCardBackground"

  /// 사진이 없는 카드·상세의 폴더 색 배경 (자리 표시: 그 색 → 흰색을 섞은 색의 대각선 그라데이션, 6단계에 같은 이름으로 교체).
  /// nil(미분류)이면 `defaultCardBackground`.
  static func cardBackground(for color: FolderColor?) -> String {
    switch color {
    case .blushPink: "FolderBackgroundBlushPink"
    case .lavender: "FolderBackgroundLavender"
    case .peach: "FolderBackgroundPeach"
    case .mint: "FolderBackgroundMint"
    case .butter: "FolderBackgroundButter"
    case nil: self.defaultCardBackground
    }
  }
}
