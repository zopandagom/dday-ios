import CoreGraphics
import Testing
@testable import Core

struct PhotoCropGeometryTests {
  private static func geometry(_ width: Int, _ height: Int) -> PhotoCropGeometry {
    PhotoCropGeometry(imageWidth: width, imageHeight: height)!
  }

  private static func isClose(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
    abs(lhs - rhs) <= tolerance
  }

  /// 영역이 이미지 안(0...1)이고 픽셀 비율이 3:2 인지.
  private static func isValid(_ rect: CGRect, in geometry: PhotoCropGeometry) -> Bool {
    let inside = rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= 1 + 1e-12 && rect.maxY <= 1 + 1e-12
      && rect.width > 0 && rect.height > 0
    let pixelRatio = (rect.width * Double(geometry.imageWidth)) / (rect.height * Double(geometry.imageHeight))
    return inside && self.isClose(pixelRatio, PhotoCropGeometry.aspectRatio, tolerance: 1e-9)
  }

  // MARK: - init

  @Test("폭이나 높이가 1 미만이면 만들지 않는다", arguments: [(0, 10), (10, 0), (-1, 10), (10, -5), (0, 0)])
  func initRejectsEmptySize(width: Int, height: Int) {
    #expect(PhotoCropGeometry(imageWidth: width, imageHeight: height) == nil)
  }

  @Test("1×1 이미지는 만든다")
  func initAcceptsOnePixel() {
    #expect(PhotoCropGeometry(imageWidth: 1, imageHeight: 1) != nil)
  }

  // MARK: - fullCropSize

  @Test(
    "확대 1 의 영역 크기: 3:2 보다 넓으면 높이 1, 아니면 폭 1",
    arguments: [
      (4000, 3000, 1.0, 4000.0 / 4500),
      (3000, 4000, 1.0, 0.5),
      (1500, 1000, 1.0, 1.0),
      (10000, 10, 0.0015, 1.0),
      (10, 10000, 1.0, 10.0 / 15000),
    ]
  )
  func fullCropSize(width: Int, height: Int, expectedWidth: Double, expectedHeight: Double) {
    let size = Self.geometry(width, height).fullCropSize
    #expect(Self.isClose(size.width, expectedWidth))
    #expect(Self.isClose(size.height, expectedHeight))
  }

  @Test("처음 영역은 가운데의 가장 큰 3:2 영역이다")
  func defaultCropIsCentered() {
    let geometry = Self.geometry(4000, 3000)
    let crop = geometry.defaultCrop
    #expect(Self.isClose(crop.midX, 0.5))
    #expect(Self.isClose(crop.midY, 0.5))
    #expect(crop.size == geometry.fullCropSize)
    #expect(Self.isValid(crop, in: geometry))
  }

  // MARK: - crop(zoom:center:)

  @Test(
    "확대 배율은 1...3 으로 맞추고 NaN·무한대는 1 이다",
    arguments: [(0.5, 1.0), (1, 1), (2, 2), (3, 3), (10, 3), (.nan, 1), (.infinity, 1), (-.infinity, 1)]
  )
  func zoomIsClamped(zoom: Double, expectedZoom: Double) {
    let geometry = Self.geometry(4000, 3000)
    let crop = geometry.crop(zoom: zoom, center: CGPoint(x: 0.5, y: 0.5))
    #expect(Self.isClose(crop.width, geometry.fullCropSize.width / expectedZoom))
    #expect(Self.isValid(crop, in: geometry))
  }

  @Test(
    "중심은 영역이 이미지 밖으로 나가지 않게 맞춘다",
    arguments: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: -5, y: 7), CGPoint(x: 0.3, y: 0.6)]
  )
  func centerIsClamped(center: CGPoint) {
    let geometry = Self.geometry(4000, 3000)
    for zoom in [1.0, 2, 3] {
      let crop = geometry.crop(zoom: zoom, center: center)
      #expect(Self.isValid(crop, in: geometry))
    }
  }

  @Test("모서리 중심은 영역을 그 모서리에 붙인다")
  func cornerCenterSticksToEdge() {
    let geometry = Self.geometry(4000, 3000)
    let topLeft = geometry.crop(zoom: 2, center: CGPoint(x: 0, y: 0))
    #expect(topLeft.origin == .zero)
    let bottomRight = geometry.crop(zoom: 2, center: CGPoint(x: 1, y: 1))
    #expect(Self.isClose(bottomRight.maxX, 1))
    #expect(Self.isClose(bottomRight.maxY, 1))
  }

  @Test("NaN·무한대 중심은 0.5 로 본다")
  func nonFiniteCenterIsHalf() {
    let geometry = Self.geometry(4000, 3000)
    let crop = geometry.crop(zoom: 2, center: CGPoint(x: Double.nan, y: Double.infinity))
    #expect(Self.isClose(crop.midX, 0.5))
    #expect(Self.isClose(crop.midY, 0.5))
  }

  @Test("극단 비율 이미지에서도 결과는 이미지 안의 3:2 영역이다", arguments: [(10000, 10), (10, 10000), (1, 1), (3, 2)])
  func extremeImages(width: Int, height: Int) {
    let geometry = Self.geometry(width, height)
    for zoom in [1.0, 1.7, 3] {
      for center in [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 1)] {
        #expect(Self.isValid(geometry.crop(zoom: zoom, center: center), in: geometry))
      }
    }
  }

  // MARK: - clamped

  @Test(
    "NaN·무한대 성분이나 폭·높이 ≤ 0 이면 처음 영역",
    arguments: [
      CGRect(x: Double.nan, y: 0, width: 0.5, height: 0.5),
      CGRect(x: 0, y: Double.infinity, width: 0.5, height: 0.5),
      CGRect(x: 0, y: 0, width: Double.nan, height: 0.5),
      CGRect(x: 0, y: 0, width: 0.5, height: -Double.infinity),
      CGRect(x: 0.1, y: 0.1, width: 0, height: 0.5),
      CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0),
      CGRect(x: 0.1, y: 0.1, width: -0.5, height: 0.5),
    ]
  )
  func clampedInvalidIsDefault(rect: CGRect) {
    let geometry = Self.geometry(4000, 3000)
    #expect(geometry.clamped(rect) == geometry.defaultCrop)
  }

  @Test("3:2 가 아닌 사각형은 중심과 폭을 유지하고 3:2 로 다시 맞춘다")
  func clampedFixesAspect() {
    let geometry = Self.geometry(4000, 3000)
    let rect = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.1)
    let clamped = geometry.clamped(rect)
    #expect(Self.isClose(clamped.width, 0.4))
    #expect(Self.isClose(clamped.midX, rect.midX))
    #expect(Self.isClose(clamped.midY, rect.midY))
    #expect(Self.isValid(clamped, in: geometry))
  }

  @Test("이미지보다 큰 사각형은 확대 1 이 된다")
  func clampedLargerIsZoomOne() {
    let geometry = Self.geometry(4000, 3000)
    let clamped = geometry.clamped(CGRect(x: -1, y: -1, width: 5, height: 5))
    #expect(clamped.size == geometry.fullCropSize)
    #expect(Self.isValid(clamped, in: geometry))
  }

  @Test("너무 작은 사각형은 확대 3 이 된다")
  func clampedSmallerIsMaxZoom() {
    let geometry = Self.geometry(4000, 3000)
    let clamped = geometry.clamped(CGRect(x: 0.5, y: 0.5, width: 0.01, height: 0.01))
    #expect(Self.isClose(clamped.width, geometry.fullCropSize.width / PhotoCropGeometry.maxZoom))
    #expect(Self.isValid(clamped, in: geometry))
  }

  @Test(
    "clamped 는 멱등이다",
    arguments: [
      CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.1),
      CGRect(x: -1, y: -1, width: 5, height: 5),
      CGRect(x: 0.9, y: 0.9, width: 0.37, height: 0.2),
      CGRect(x: 0.123, y: 0.456, width: 0.333, height: 0.777),
      CGRect(x: Double.nan, y: 0, width: 1, height: 1),
    ]
  )
  func clampedIsIdempotent(rect: CGRect) {
    for geometry in [
      Self.geometry(4000, 3000),
      Self.geometry(3000, 4000),
      Self.geometry(10000, 10),
      Self.geometry(7, 3),
    ] {
      let once = geometry.clamped(rect)
      #expect(geometry.clamped(once) == once)
    }
  }

  @Test("crop(zoom:center:) 의 결과는 clamped 를 거쳐도 그대로다")
  func cropResultIsClampedFixedPoint() {
    let geometry = Self.geometry(4000, 3000)
    let crop = geometry.crop(zoom: 1.37, center: CGPoint(x: 0.21, y: 0.83))
    #expect(geometry.clamped(crop) == crop)
  }

  // MARK: - pixelRect

  @Test(
    "픽셀 사각형은 정수이고 이미지 안이며 폭·높이 ≥ 1 이다",
    arguments: [(4000, 3000), (3000, 4000), (10000, 10), (10, 10000), (7, 3), (2, 2)]
  )
  func pixelRectIsInside(width: Int, height: Int) {
    let geometry = Self.geometry(width, height)
    for zoom in [1.0, 2, 3] {
      for center in [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 1)] {
        let rect = geometry.pixelRect(for: geometry.crop(zoom: zoom, center: center))
        #expect(rect.minX == rect.minX.rounded() && rect.minY == rect.minY.rounded())
        #expect(rect.width == rect.width.rounded() && rect.height == rect.height.rounded())
        #expect(rect.width >= 1 && rect.height >= 1)
        #expect(rect.minX >= 0 && rect.minY >= 0)
        #expect(rect.maxX <= Double(width) && rect.maxY <= Double(height))
      }
    }
  }

  @Test("1×1 이미지의 픽셀 사각형은 (0,0,1,1)")
  func pixelRectOnePixel() {
    let geometry = Self.geometry(1, 1)
    #expect(geometry.pixelRect(for: geometry.defaultCrop) == CGRect(x: 0, y: 0, width: 1, height: 1))
  }

  @Test("오른쪽 아래 끝 영역은 이미지를 넘지 않는다")
  func pixelRectBottomRight() {
    let geometry = Self.geometry(4001, 3001)
    let rect = geometry.pixelRect(for: geometry.crop(zoom: 3, center: CGPoint(x: 1, y: 1)))
    #expect(rect.maxX <= 4001 && rect.maxY <= 3001)
    #expect(rect.maxX >= 4000 && rect.maxY >= 3000)
  }

  @Test("가로 4:3 이미지의 처음 영역은 폭 전체·높이 폭/1.5")
  func pixelRectDefault() {
    let geometry = Self.geometry(4000, 3000)
    let rect = geometry.pixelRect(for: geometry.defaultCrop)
    #expect(rect == CGRect(x: 0, y: 167, width: 4000, height: 2667))
  }

  @Test("범위 밖 사각형은 clamped 를 거쳐 픽셀 사각형이 된다")
  func pixelRectClampsInput() {
    let geometry = Self.geometry(4000, 3000)
    #expect(geometry.pixelRect(for: CGRect(x: Double.nan, y: 0, width: 1, height: 1)) == geometry
      .pixelRect(for: geometry.defaultCrop))
  }

  // MARK: - outputSize

  @Test(
    "출력 크기는 긴 변 최대로 줄이고 키우지 않는다",
    arguments: [
      (3200, 1600, 1600, 1067),
      (1600, 1600, 1600, 1067),
      (1599, 1600, 1599, 1066),
      (900, 1600, 900, 600),
      (1, 1600, 1, 1),
      (3200, 400, 400, 267),
      (0, 400, 1, 1),
    ]
  )
  func outputSize(cropPixelWidth: Int, maxLongSide: Int, width: Int, height: Int) {
    let size = PhotoCropGeometry.outputSize(cropPixelWidth: cropPixelWidth, maxLongSide: maxLongSide)
    #expect(size.width == width)
    #expect(size.height == height)
  }
}
