import Core
import CoreGraphics
import Foundation
import ImageIO
import PhotoInterface
import Synchronization
import UniformTypeIdentifiers

/// 실제 이미지로 도는 사진 처리 Fake (Testing 은 Impl 을 쓸 수 없어 같은 출력 크기 규칙으로 따로 구현한다).
///
/// - `loadWorkingImage`: 먼저 `picked.loadData()` 를 부르고(던지면 그대로), `delay` 만큼 기다린 뒤 `failNextLoad` 로
///   넣은 에러가 있으면 던진다. 없으면 방향 반영·긴 변 ≤ 3200 으로 디코딩하고 실패하면 `.decodeFailed`.
///   한도 검사는 하지 않는다 (`.tooLarge` 는 `failNextLoad` 로만).
/// - `renderCardPhoto`: 받은 crop(보정 전 값)을 기록하고, `delay` 뒤 넣은 에러가 있으면 던진다. 없으면 Core
///   `PhotoCropGeometry` 로 잘라 Impl 과 같은 크기의 JPEG 두 벌(메타데이터 없음)을 만든다.
/// 지연 중 취소는 보지 않는다. 잠금은 지연 동안 잡지 않으므로 다른 호출이 막히지 않는다.
public final class PhotoClientFake: PhotoClient {
  private struct State {
    var nextLoadError: PhotoError?
    var nextRenderError: PhotoError?
    var loadCount = 0
    var renderedCrops: [CGRect] = []
  }

  private let state = Mutex(State())
  private let delay: Duration?

  public init(delay: Duration? = nil) {
    self.delay = delay
  }

  /// 다음 `loadWorkingImage` 한 번이 `error` 로 실패한다 (`loadData()` 가 먼저 실패하면 쓰이지 않고 남는다).
  public func failNextLoad(with error: PhotoError) {
    self.state.withLock { $0.nextLoadError = error }
  }

  /// 다음 `renderCardPhoto` 한 번이 `error` 로 실패한다.
  public func failNextRender(with error: PhotoError) {
    self.state.withLock { $0.nextRenderError = error }
  }

  /// `loadWorkingImage` 를 부른 횟수.
  public var loadCount: Int {
    self.state.withLock { $0.loadCount }
  }

  /// `renderCardPhoto` 가 받은 crop (보정 전 값), 부른 순서.
  public var renderedCrops: [CGRect] {
    self.state.withLock { $0.renderedCrops }
  }

  public func loadWorkingImage(from picked: PickedPhoto) async throws(PhotoError) -> PhotoWorkingImage {
    self.state.withLock { $0.loadCount += 1 }
    let data = try await picked.loadData()
    await self.wait()
    if let error = self.state.withLock({ $0.nextLoadError.take() }) {
      throw error
    }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: PhotoWorkingImage.maxLongSide,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) > 0,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    else { throw .decodeFailed }
    return PhotoWorkingImage(image: image)
  }

  public func renderCardPhoto(from image: PhotoWorkingImage, crop: CGRect) async throws(PhotoError) -> CardPhoto {
    self.state.withLock { $0.renderedCrops.append(crop) }
    await self.wait()
    if let error = self.state.withLock({ $0.nextRenderError.take() }) {
      throw error
    }
    guard let geometry = image.geometry,
          let cropped = image.image.cropping(to: geometry.pixelRect(for: crop)),
          let full = Self.jpeg(from: cropped, maxLongSide: PhotoCropGeometry.imageMaxLongSide),
          let thumbnail = Self.jpeg(from: cropped, maxLongSide: PhotoCropGeometry.thumbnailMaxLongSide)
    else { throw .renderFailed }
    return CardPhoto(image: full, thumbnail: thumbnail)
  }

  // MARK: - 내부

  /// 취소와 상관없이 `delay` 만큼 기다린다 (부른 Task 가 취소돼도 따로 도는 Task 가 끝까지 잔다).
  private func wait() async {
    guard let delay = self.delay else { return }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      Task {
        try? await Task.sleep(for: delay)
        continuation.resume()
      }
    }
  }

  private static func jpeg(from cropped: CGImage, maxLongSide: Int) -> Data? {
    let size = PhotoCropGeometry.outputSize(cropPixelWidth: cropped.width, maxLongSide: maxLongSide)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
          let context = CGContext(
            data: nil,
            width: size.width,
            height: size.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          )
    else { return nil }
    let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(bounds)
    context.interpolationQuality = .high
    context.draw(cropped, in: bounds)
    guard let drawn = context.makeImage() else { return nil }
    let properties = [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
    return PhotoSamples.encode(drawn, type: .jpeg, properties: properties)
  }
}
