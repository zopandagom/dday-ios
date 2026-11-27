import Core
import CoreGraphics
import Foundation
import ImageIO
import PhotoInterface
import UniformTypeIdentifiers

/// 사진 처리의 순수 단계 (ImageIO·CoreGraphics). `PhotoClientImpl` 이 순서대로 부르고 테스트가 `@testable` 로 부른다.
/// 원본 속성(EXIF·GPS·TIFF 등)은 어디에도 넘기지 않는다: 크기 검사에만 읽고, 인코딩에는 압축 품질만 준다.
enum PhotoRendering {
  /// JPEG 압축 품질.
  static let jpegQuality = 0.8

  /// 데이터 → 이미지 소스. 이미지가 아니면(형식 없음·이미지 0장) `.decodeFailed`.
  static func makeSource(_ data: Data) throws(PhotoError) -> CGImageSource {
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, options),
          CGImageSourceGetType(source) != nil,
          CGImageSourceGetCount(source) > 0
    else { throw .decodeFailed }
    return source
  }

  /// 첫 이미지의 픽셀 크기 (방향 반영 전). 크기 정보가 없으면 `.decodeFailed`.
  /// 속성 사전은 크기를 읽는 데만 쓰고 버린다.
  static func pixelSize(of source: CGImageSource) throws(PhotoError) -> (width: Int, height: Int) {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
          let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
    else { throw .decodeFailed }
    return (width, height)
  }

  /// 방향을 픽셀에 반영하고 긴 변 ≤ `maxLongSide` 로 디코딩한다 (원본보다 키우지 않는다).
  /// `FromImageAlways` 로 EXIF 안의 작은 내장 썸네일을 쓰지 않는다. 실패하면 `.decodeFailed`.
  static func decodeWorkingImage(
    from source: CGImageSource,
    maxLongSide: Int = PhotoWorkingImage.maxLongSide
  ) throws(PhotoError) -> CGImage {
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: maxLongSide,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { throw .decodeFailed }
    return image
  }

  /// 작업 이미지를 `crop`(정규화, clamped 로 다시 맞춤) 으로 잘라 압축본·썸네일 JPEG 을 만든다. 실패하면 `.renderFailed`.
  static func renderCardPhoto(from image: CGImage, crop: CGRect) throws(PhotoError) -> CardPhoto {
    guard let geometry = PhotoCropGeometry(imageWidth: image.width, imageHeight: image.height) else {
      throw .renderFailed
    }
    let rect = geometry.pixelRect(for: geometry.clamped(crop))
    guard let cropped = image.cropping(to: rect) else { throw .renderFailed }
    let full = try self.jpeg(from: cropped, maxLongSide: PhotoCropGeometry.imageMaxLongSide)
    let thumbnail = try self.jpeg(from: cropped, maxLongSide: PhotoCropGeometry.thumbnailMaxLongSide)
    return CardPhoto(image: full, thumbnail: thumbnail)
  }

  /// 자른 이미지 → `outputSize` 크기로 그린 JPEG.
  static func jpeg(from cropped: CGImage, maxLongSide: Int) throws(PhotoError) -> Data {
    let size = PhotoCropGeometry.outputSize(cropPixelWidth: cropped.width, maxLongSide: maxLongSide)
    guard let drawn = self.draw(cropped, width: size.width, height: size.height),
          let data = self.encodeJPEG(drawn)
    else { throw .renderFailed }
    return data
  }

  /// Display P3 8bit 불투명 비트맵에 흰 배경(투명 영역이 검게 되지 않게)을 깔고 고품질 보간으로 그린다.
  static func draw(_ image: CGImage, width: Int, height: Int) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3),
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          )
    else { return nil }
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(bounds)
    context.interpolationQuality = .high
    context.draw(image, in: bounds)
    return context.makeImage()
  }

  /// JPEG 인코딩. 압축 품질 말고는 어떤 속성·원본 소스도 넘기지 않는다 (메타데이터 없음).
  static func encodeJPEG(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
      return nil
    }
    let properties = [kCGImageDestinationLossyCompressionQuality: self.jpegQuality] as CFDictionary
    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }
}
