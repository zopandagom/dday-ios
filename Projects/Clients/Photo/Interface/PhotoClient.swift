import Core
import CoreGraphics

/// 고른 사진을 자르기용 작업 이미지로 읽고, 자른 영역으로 카드 사진(압축본·썸네일 JPEG)을 만든다.
/// 결과에는 원본 메타데이터(위치·기기·촬영 정보)가 없고, 방향은 픽셀에 반영된다.
public protocol PhotoClient: Sendable {
  /// `picked.loadData()` 로 읽고 → 한도 검사 → 방향 반영·긴 변 ≤ `PhotoWorkingImage.maxLongSide` 디코딩.
  /// `.readFailed`(읽기 실패·취소) / `.tooLarge` / `.decodeFailed`.
  func loadWorkingImage(from picked: PickedPhoto) async throws(PhotoError) -> PhotoWorkingImage
  /// `crop`(정규화 영역) 을 `PhotoCropGeometry.clamped` 로 다시 맞춰 자르고 압축본·썸네일 JPEG 을 만든다.
  /// `.renderFailed`.
  func renderCardPhoto(from image: PhotoWorkingImage, crop: CGRect) async throws(PhotoError) -> CardPhoto
}
