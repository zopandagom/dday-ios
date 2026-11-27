import Foundation

/// 카드 사진 한 장: 3:2 로 자른 JPEG 두 벌. 원본 메타데이터는 없다 (Photo Client 가 만든다).
public struct CardPhoto: Hashable, Sendable {
  /// 압축본. 긴 변(폭) 최대 `PhotoCropGeometry.imageMaxLongSide`.
  public let image: Data
  /// 썸네일. 긴 변(폭) 최대 `PhotoCropGeometry.thumbnailMaxLongSide`. 목록은 이것만 쓴다.
  public let thumbnail: Data

  public init(image: Data, thumbnail: Data) {
    self.image = image
    self.thumbnail = thumbnail
  }
}
