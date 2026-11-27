import Core
import CoreGraphics
import Foundation
import os
import PhotoInterface

/// ImageIO·CoreGraphics 로 사진을 처리한다. 저장 상태가 없고 처리는 `@concurrent` 로 메인 밖에서 한다.
///
/// - `loadWorkingImage`: 읽기 → 바이트 한도 → 이미지 소스 → 픽셀 한도(디코딩 전) → 방향 반영·긴 변 ≤ 3200 디코딩.
///   `loadData()` 뒤와 디코딩 직전에 Task 취소를 보고, 취소됐으면 `.readFailed` 를 던진다.
///   이미 시작한 ImageIO 디코딩 한 번은 끊을 수 없어 끝까지 돈다.
/// - `renderCardPhoto`: 영역을 다시 맞춰 자르고 압축본(긴 변 ≤ 1600)·썸네일(≤ 400) JPEG 을 만든다. 취소는 보지 않는다.
/// 로그에는 단계 이름·에러 종류만 남긴다 (크기·데이터는 남기지 않는다).
public final class PhotoClientImpl: PhotoClient {
  private static let logger = Logger(subsystem: "com.zopandagom.dday", category: "Photo")

  let limits: PhotoInputLimits

  public convenience init() {
    self.init(limits: .default)
  }

  init(limits: PhotoInputLimits) {
    self.limits = limits
  }

  @concurrent
  public func loadWorkingImage(from picked: PickedPhoto) async throws(PhotoError) -> PhotoWorkingImage {
    let data: Data
    do throws(PhotoError) {
      data = try await picked.loadData()
    } catch {
      Self.log("read", error)
      throw error
    }
    do throws(PhotoError) {
      try Self.checkCancellation()
      if let error = self.limits.check(byteCount: data.count) {
        throw error
      }
      let source = try PhotoRendering.makeSource(data)
      let size = try PhotoRendering.pixelSize(of: source)
      if let error = self.limits.check(pixelWidth: size.width, pixelHeight: size.height) {
        throw error
      }
      try Self.checkCancellation()
      let image = try PhotoRendering.decodeWorkingImage(from: source)
      return PhotoWorkingImage(image: image)
    } catch {
      Self.log("load", error)
      throw error
    }
  }

  @concurrent
  public func renderCardPhoto(from image: PhotoWorkingImage, crop: CGRect) async throws(PhotoError) -> CardPhoto {
    do throws(PhotoError) {
      return try PhotoRendering.renderCardPhoto(from: image.image, crop: crop)
    } catch {
      Self.log("render", error)
      throw error
    }
  }

  private static func checkCancellation() throws(PhotoError) {
    if Task.isCancelled {
      throw .readFailed
    }
  }

  private static func log(_ step: String, _ error: PhotoError) {
    self.logger.error("photo \(step, privacy: .public) failed: \(String(describing: error), privacy: .public)")
  }
}
