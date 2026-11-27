import CoreGraphics
import Foundation

/// 카드 사진 3:2 자르기 영역 규칙.
///
/// 좌표: 작업 이미지(방향 반영 후) 기준 정규화 값 0...1, 원점 왼쪽 위 (`CGImage.cropping(to:)` 의 픽셀 좌표와 같은 방향).
/// 영역 크기는 폭으로 정한다: 폭 = `fullCropSize.width / zoom` (zoom 1...`maxZoom`), 높이 = 폭에 비례.
/// 유효 영역은 늘 이미지 안이고 픽셀 비율이 3:2 다.
public struct PhotoCropGeometry: Equatable, Sendable {
  /// 폭 / 높이 (픽셀).
  public static let aspectRatio: Double = 1.5
  public static let maxZoom: Double = 3
  /// 압축본 긴 변(폭) 최대.
  public static let imageMaxLongSide = 1600
  /// 썸네일 긴 변(폭) 최대.
  public static let thumbnailMaxLongSide = 400

  public let imageWidth: Int
  public let imageHeight: Int

  /// 폭·높이 중 하나라도 1 미만이면 nil.
  public init?(imageWidth: Int, imageHeight: Int) {
    guard imageWidth >= 1, imageHeight >= 1 else { return nil }
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
  }

  /// 확대 1 의 영역 크기(정규화): 이미지가 3:2 보다 넓으면 높이 1, 아니면 폭 1.
  ///   W/H ≥ 1.5 → (w: 1.5·H/W, h: 1),  그 밖 → (w: 1, h: W/(1.5·H))
  public var fullCropSize: CGSize {
    let width = Double(self.imageWidth)
    let height = Double(self.imageHeight)
    if width >= Self.aspectRatio * height {
      return CGSize(width: Self.aspectRatio * height / width, height: 1)
    }
    return CGSize(width: 1, height: width / (Self.aspectRatio * height))
  }

  /// 가운데의 가장 큰 3:2 영역 (자르기 화면 처음 값).
  public var defaultCrop: CGRect {
    self.makeCrop(width: self.fullCropSize.width, center: CGPoint(x: 0.5, y: 0.5))
  }

  /// 제스처 값 → 유효 영역. zoom 은 1...maxZoom 으로(NaN·무한대는 1), 크기 = fullCropSize / zoom,
  /// center 는 영역이 이미지 밖으로 나가지 않게 [w/2, 1-w/2]×[h/2, 1-h/2] 로 (NaN·무한대는 0.5).
  public func crop(zoom: Double, center: CGPoint) -> CGRect {
    let zoom = zoom.isFinite ? min(max(zoom, 1), Self.maxZoom) : 1
    return self.makeCrop(width: self.fullCropSize.width / zoom, center: center)
  }

  /// 아무 사각형 → 유효 영역 (최종 보정, Model·Impl 이 부른다. 멱등):
  /// 성분에 NaN·무한대가 있거나 폭·높이 ≤ 0 이면 defaultCrop. 아니면 중심을 유지하고
  /// zoom = fullCropSize.width / rect.width 로 보고 crop(zoom:center:) 와 같게 맞춘다 (높이는 무시하고 3:2 로 다시 계산).
  public func clamped(_ rect: CGRect) -> CGRect {
    let components = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    guard components.allSatisfy(\.isFinite), rect.size.width > 0, rect.size.height > 0 else {
      return self.defaultCrop
    }
    // 이미 유효한 영역은 그대로 돌려준다 (중심을 다시 계산하면 부동소수 오차로 값이 흔들려 멱등이 깨진다).
    if self.isValid(rect) {
      return rect
    }
    return self.makeCrop(width: rect.size.width, center: CGPoint(x: rect.midX, y: rect.midY))
  }

  /// 정규화 영역(clamped 를 거친다) → 작업 이미지 픽셀 사각형. 정수, 이미지 안, 폭·높이 ≥ 1.
  /// 폭 = max(1, round(w·W)), 높이 = max(1, round(폭 / 1.5)) 를 이미지 높이 이하로, 원점은 이미지 안으로 맞춘다.
  public func pixelRect(for crop: CGRect) -> CGRect {
    let crop = self.clamped(crop)
    let width = min(max(1, Int((crop.size.width * Double(self.imageWidth)).rounded())), self.imageWidth)
    let height = min(max(1, Int((Double(width) / Self.aspectRatio).rounded())), self.imageHeight)
    let x = min(max(0, Int((crop.origin.x * Double(self.imageWidth)).rounded())), self.imageWidth - width)
    let y = min(max(0, Int((crop.origin.y * Double(self.imageHeight)).rounded())), self.imageHeight - height)
    return CGRect(x: x, y: y, width: width, height: height)
  }

  /// 출력 크기: 폭 = min(maxLongSide, cropPixelWidth) (키우지 않는다), 높이 = max(1, round(폭 / 1.5)).
  /// 폭도 1 이상으로 맞춘다.
  public static func outputSize(cropPixelWidth: Int, maxLongSide: Int) -> (width: Int, height: Int) {
    let width = max(1, min(maxLongSide, cropPixelWidth))
    let height = max(1, Int((Double(width) / Self.aspectRatio).rounded()))
    return (width, height)
  }

  // MARK: - 내부

  /// 폭 하나로 정한 영역 크기의 범위: [fullCropSize.width / maxZoom, fullCropSize.width].
  private func clampedWidth(_ width: Double) -> Double {
    let full = self.fullCropSize.width
    return min(max(width, full / Self.maxZoom), full)
  }

  /// 폭에 맞는 3:2 높이 (정규화). 폭이 fullCropSize.width 면 정확히 fullCropSize.height.
  private func height(forWidth width: Double) -> Double {
    let full = self.fullCropSize
    return full.height * (width / full.width)
  }

  private func isValid(_ rect: CGRect) -> Bool {
    let width = rect.size.width
    guard self.clampedWidth(width) == width, rect.size.height == self.height(forWidth: width) else { return false }
    return (0 ... max(0, 1 - width)).contains(rect.origin.x)
      && (0 ... max(0, 1 - rect.size.height)).contains(rect.origin.y)
  }

  /// 폭(범위로 맞춤)·중심(비유한 값은 0.5) → 이미지 안의 유효 영역.
  private func makeCrop(width: Double, center: CGPoint) -> CGRect {
    let width = self.clampedWidth(width)
    let height = self.height(forWidth: width)
    let centerX = center.x.isFinite ? center.x : 0.5
    let centerY = center.y.isFinite ? center.y : 0.5
    let x = min(max(centerX - width / 2, 0), max(0, 1 - width))
    let y = min(max(centerY - height / 2, 0), max(0, 1 - height))
    return CGRect(x: x, y: y, width: width, height: height)
  }
}
