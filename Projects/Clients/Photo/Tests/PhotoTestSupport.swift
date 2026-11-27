import CoreGraphics
import Foundation
import ImageIO
import PhotoInterface
import PhotoTesting
import UniformTypeIdentifiers
@testable import PhotoImpl

/// 사진 테스트 도우미. 테스트라 강제 언래핑을 쓴다.
enum PhotoTest {
  /// 대략의 색 이름 (JPEG 손실·색 공간 변환을 견디도록 채널을 0.5 로 나눈다).
  enum Color: Equatable {
    case red, green, blue, yellow, white, black, other
  }

  static func picked(_ data: Data) -> PickedPhoto {
    PickedPhoto { data }
  }

  static func failingPicked(_ error: PhotoError = .readFailed) -> PickedPhoto {
    PickedPhoto { () async throws(PhotoError) -> Data in throw error }
  }

  static func image(from data: Data) -> CGImage {
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
  }

  static func typeIdentifier(of data: Data) -> String? {
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    return CGImageSourceGetType(source) as String?
  }

  static func pixelSize(of data: Data) -> (width: Int, height: Int) {
    let image = self.image(from: data)
    return (image.width, image.height)
  }

  /// 정규화 위치(원점 왼쪽 위)의 색.
  static func color(of image: CGImage, x: Double, y: Double) -> Color {
    let width = 64
    let height = 64
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
      data: &pixels,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    // 비트맵 메모리의 첫 줄이 이미지의 위쪽이다.
    let column = min(width - 1, Int(x * Double(width)))
    let row = min(height - 1, Int(y * Double(height)))
    let offset = (row * width + column) * 4
    let channels = (pixels[offset] > 128, pixels[offset + 1] > 128, pixels[offset + 2] > 128)
    switch channels {
    case (true, false, false): return .red
    case (false, true, false): return .green
    case (false, false, true): return .blue
    case (true, true, false): return .yellow
    case (true, true, true): return .white
    case (false, false, false): return .black
    default: return .other
    }
  }

  static func color(of data: Data, x: Double, y: Double) -> Color {
    self.color(of: self.image(from: data), x: x, y: y)
  }

  /// 사분면 샘플을 Impl 로 디코딩한 작업 이미지.
  static func workingImage(width: Int, height: Int, orientation: Int = 1) throws -> PhotoWorkingImage {
    let data = PhotoSamples.jpegData(width: width, height: height, orientation: orientation)
    let source = try PhotoRendering.makeSource(data)
    return try PhotoWorkingImage(image: PhotoRendering.decodeWorkingImage(from: source))
  }

  /// 완전히 투명한 PNG 작업 이미지.
  static func transparentImage(width: Int, height: Int) -> PhotoWorkingImage {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    _ = CGImageDestinationFinalize(destination)
    return PhotoWorkingImage(image: self.image(from: data as Data))
  }

  /// 이미지 속성 사전 (메타데이터 확인용).
  static func properties(of data: Data) -> [String: Any] {
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
  }

  /// XMP 태그 이름 ("prefix:name").
  static func xmpTagNames(of data: Data) -> Set<String> {
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    guard let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
          let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag]
    else { return [] }
    return Set(tags.compactMap { tag in
      guard let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
            let name = CGImageMetadataTagCopyName(tag) as String?
      else { return nil }
      return "\(prefix):\(name)"
    })
  }
}
