import Core
import CoreGraphics

/// 자르기용 작업 이미지: 방향을 픽셀에 반영했고 긴 변 최대 `maxLongSide` (원본보다 키우지 않는다).
/// `CGImage` 는 SDK 가 Sendable 로 선언한 불변 객체라 그대로 담는다.
public struct PhotoWorkingImage: Equatable, Sendable {
  public static let maxLongSide = 3200

  public let image: CGImage

  public var width: Int { self.image.width }
  public var height: Int { self.image.height }
  /// 이 이미지의 자르기 영역 규칙. 크기가 0 이면 nil.
  public var geometry: PhotoCropGeometry? {
    PhotoCropGeometry(imageWidth: self.width, imageHeight: self.height)
  }

  public init(image: CGImage) {
    self.image = image
  }

  /// 같은 이미지 객체일 때만 같다 (픽셀 비교 안 함).
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.image === rhs.image
  }
}
