import Core
import CoreGraphics
import Foundation

/// 자르기 화면의 진행 중인 끌기·확대 (View 의 `@GestureState`). 화면 표시와 확정이 같은 값·같은 계산을 쓰도록
/// 순수 계산을 여기에 모은다 ("보이는 영역 = 확정 영역").
///
/// - 부분 제스처(끌기·확대)의 값이 비면(nil, 그 제스처가 끝남: 한 손가락을 떼고 계속 끌기) 마지막 값을 유지한다.
/// - 비었던 제스처에 다시 값이 오면 새 구간으로 보고 그때까지의 값 위에 쌓는다 (한 손가락을 뗐다가 다시 대고
///   확대해도 앞서 확대한 값이 사라지지 않는다).
struct CropGesture: Equatable {
  /// 쌓은 끈 거리(포인트).
  private(set) var translation: CGSize = .zero
  /// 쌓은 확대 배율.
  private(set) var magnification: Double = 1
  private var translationBase: CGSize = .zero
  private var magnificationBase: Double = 1
  private var isDragging = false
  private var isPinching = false

  /// 확정된 확대·중심.
  struct Committed: Equatable {
    var zoom: Double
    var center: CGPoint
  }

  /// 부분 제스처의 이번 값을 반영한 값. 같은 구간의 값은 쌓지 않고 바꾼다 (값은 구간 시작부터의 누계다).
  func updated(translation newTranslation: CGSize?, magnification newMagnification: Double?) -> Self {
    var next = self
    if let newTranslation {
      if !next.isDragging {
        next.translationBase = next.translation
        next.isDragging = true
      }
      next.translation = CGSize(
        width: next.translationBase.width + newTranslation.width,
        height: next.translationBase.height + newTranslation.height
      )
    } else {
      next.isDragging = false
    }
    if let newMagnification, newMagnification.isFinite, newMagnification > 0 {
      if !next.isPinching {
        next.magnificationBase = next.magnification
        next.isPinching = true
      }
      next.magnification = next.magnificationBase * newMagnification
    } else {
      next.isPinching = false
    }
    return next
  }

  /// 확정 값에 이 제스처를 더한 영역: 확대를 곱하고, 끈 거리를 그 확대의 표시 크기로 정규화해 중심에서 뺀 뒤
  /// 클램프한다 (오른쪽으로 끌면 왼쪽이 보인다).
  func crop(_ geometry: PhotoCropGeometry, frameWidth: Double, committed: Committed) -> CGRect {
    let zoom = committed.zoom * self.magnification
    let base = geometry.crop(zoom: zoom, center: committed.center)
    let size = Self.displaySize(geometry, crop: base, frameWidth: frameWidth)
    guard size.width > 0, size.height > 0 else { return base }
    let center = CGPoint(
      x: committed.center.x - self.translation.width / size.width,
      y: committed.center.y - self.translation.height / size.height
    )
    return geometry.crop(zoom: zoom, center: center)
  }

  /// 끝난 제스처를 반영한 새 확정 값. 이 값으로 `geometry.crop(zoom:center:)` 하면 `crop(_:frameWidth:committed:)` 와 같다.
  func committing(_ geometry: PhotoCropGeometry, frameWidth: Double, committed: Committed) -> Committed {
    let crop = self.crop(geometry, frameWidth: frameWidth, committed: committed)
    let zoom = committed.zoom * self.magnification
    return Committed(
      zoom: zoom.isFinite ? min(max(zoom, 1), PhotoCropGeometry.maxZoom) : 1,
      center: CGPoint(x: crop.midX, y: crop.midY)
    )
  }

  /// 영역이 틀을 채우도록 그린 작업 이미지 전체의 크기 (포인트).
  static func displaySize(_ geometry: PhotoCropGeometry, crop: CGRect, frameWidth: Double) -> CGSize {
    guard crop.width > 0 else { return .zero }
    let width = frameWidth / crop.width
    return CGSize(width: width, height: width * Double(geometry.imageHeight) / Double(geometry.imageWidth))
  }
}
