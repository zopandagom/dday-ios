import Core
import CoreGraphics
import Foundation
import Testing
@testable import DDayEditorFeature

/// 자르기 제스처 값 합치기와 "보이는 영역 = 확정 영역" (`CropGesture`).
struct CropGestureTests {
  /// 3200×2400 작업 이미지, 틀 폭 300pt.
  let geometry = PhotoCropGeometry(imageWidth: 3200, imageHeight: 2400)!
  let frameWidth = 300.0
  let start = CropGesture.Committed(zoom: 1, center: CGPoint(x: 0.5, y: 0.5))

  @Test("한쪽 제스처 값이 비면 그 제스처의 마지막 값을 유지한다")
  func nilKeepsLastValue() {
    let gesture = CropGesture()
      .updated(translation: CGSize(width: 10, height: 5), magnification: 2)
      .updated(translation: CGSize(width: 30, height: 5), magnification: nil)
    #expect(gesture.translation == CGSize(width: 30, height: 5))
    #expect(gesture.magnification == 2)

    let both = gesture.updated(translation: nil, magnification: nil)
    #expect(both.translation == CGSize(width: 30, height: 5))
    #expect(both.magnification == 2)
  }

  @Test("같은 구간의 값은 쌓지 않고 바꾼다 (구간 시작부터의 누계)")
  func sameSegmentReplaces() {
    let gesture = CropGesture()
      .updated(translation: CGSize(width: 10, height: 0), magnification: 1.5)
      .updated(translation: CGSize(width: 20, height: 0), magnification: 1.8)
    #expect(gesture.translation == CGSize(width: 20, height: 0))
    #expect(gesture.magnification == 1.8)
  }

  @Test("비었던 제스처가 다시 시작되면 그때까지의 값 위에 쌓는다 (다시 대고 확대·끌기)")
  func restartedSegmentAccumulates() {
    let gesture = CropGesture()
      .updated(translation: CGSize(width: 10, height: 0), magnification: 2)
      .updated(translation: nil, magnification: nil)
      .updated(translation: CGSize(width: 5, height: 4), magnification: 1.5)
    #expect(gesture.translation == CGSize(width: 15, height: 4))
    #expect(gesture.magnification == 3)
  }

  @Test("유효하지 않은 배율은 그 제스처가 끝난 것으로 본다", arguments: [0, -1, Double.nan, Double.infinity])
  func invalidMagnification(value: Double) {
    let gesture = CropGesture()
      .updated(translation: nil, magnification: 2)
      .updated(translation: nil, magnification: value)
    #expect(gesture.magnification == 2)
  }

  @Test("확정 값으로 다시 만든 영역은 손을 떼기 직전 화면의 영역과 같다", arguments: [
    (CGSize(width: 40, height: -20), 1.6),
    (CGSize(width: -500, height: 500), 1.0),
    (CGSize(width: 15, height: 10), 5.0),
    (CGSize.zero, 0.5),
  ])
  func committedMatchesLiveCrop(translation: CGSize, magnification: Double) {
    let gesture = CropGesture().updated(translation: translation, magnification: magnification)
    let live = gesture.crop(self.geometry, frameWidth: self.frameWidth, committed: self.start)
    let committed = gesture.committing(self.geometry, frameWidth: self.frameWidth, committed: self.start)
    let rebuilt = self.geometry.crop(zoom: committed.zoom, center: committed.center)
    #expect(abs(rebuilt.minX - live.minX) < 1e-9)
    #expect(abs(rebuilt.minY - live.minY) < 1e-9)
    #expect(abs(rebuilt.width - live.width) < 1e-9)
    #expect(abs(rebuilt.height - live.height) < 1e-9)
    #expect((1 ... PhotoCropGeometry.maxZoom).contains(committed.zoom))
  }

  @Test("제스처가 없으면 확정 값이 바뀌지 않는다")
  func emptyGestureKeepsCommitted() {
    let committed = CropGesture().committing(self.geometry, frameWidth: self.frameWidth, committed: self.start)
    #expect(committed.zoom == self.start.zoom)
    #expect(abs(committed.center.x - self.start.center.x) < 1e-9)
    #expect(abs(committed.center.y - self.start.center.y) < 1e-9)
  }
}
