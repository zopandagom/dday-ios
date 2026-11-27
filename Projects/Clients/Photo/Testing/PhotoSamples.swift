import Core
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 테스트·Example 용 샘플 사진 (직접 그린 이미지, 개인 데이터 없음).
/// 프로덕션 규칙(강제 언래핑 금지)을 따라 만들기 실패는 빈 `Data` 를 돌려준다.
public enum PhotoSamples {
  /// 사분면 색(왼쪽 위 빨강·오른쪽 위 초록·왼쪽 아래 파랑·오른쪽 아래 노랑)으로 그린 JPEG.
  /// - Parameters:
  ///   - width: 저장된 픽셀 폭 (방향 반영 전).
  ///   - orientation: EXIF 방향 값 (1...8). 표시할 때 회전된다.
  ///   - includesPrivateMetadata: EXIF(DateTimeOriginal·LensModel)·GPS·TIFF(Make·Model) 를 넣는다 (메타데이터 테스트용).
  public static func jpegData(
    width: Int,
    height: Int,
    orientation: Int = 1,
    includesPrivateMetadata: Bool = false
  ) -> Data {
    self.imageData(
      width: width,
      height: height,
      orientation: orientation,
      includesPrivateMetadata: includesPrivateMetadata,
      type: .jpeg
    )
  }

  /// `jpegData` 와 같은 그림을 `type`(JPEG·HEIC·PNG 등) 으로 인코딩한다.
  public static func imageData(
    width: Int,
    height: Int,
    orientation: Int = 1,
    includesPrivateMetadata: Bool = false,
    type: UTType
  ) -> Data {
    guard let image = self.quadrantImage(width: width, height: height) else { return Data() }
    var properties: [CFString: Any] = [
      kCGImagePropertyOrientation: orientation,
      kCGImageDestinationLossyCompressionQuality: 0.9,
    ]
    if includesPrivateMetadata {
      properties[kCGImagePropertyExifDictionary] = [
        kCGImagePropertyExifDateTimeOriginal: "2024:05:01 10:20:30",
        kCGImagePropertyExifLensModel: "Sample Lens 1.0",
      ]
      properties[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: 37.5665,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 126.978,
        kCGImagePropertyGPSLongitudeRef: "E",
      ]
      properties[kCGImagePropertyTIFFDictionary] = [
        kCGImagePropertyTIFFMake: "SampleMaker",
        kCGImagePropertyTIFFModel: "SampleModel X",
      ]
    }
    return self.encode(image, type: type, properties: properties as CFDictionary) ?? Data()
  }

  /// 작은 3:2 카드 사진 (압축본 60×40, 썸네일 30×20). seed 마다 색이 다르고 image ≠ thumbnail.
  public static func cardPhoto(seed: Int = 0) -> CardPhoto {
    let hue = Double(abs(seed) % 12) / 12
    let color = CGColor(red: hue, green: 1 - hue, blue: 0.5, alpha: 1)
    let image = self.solidImage(width: 60, height: 40, color: color).flatMap { self.encode($0, type: .jpeg) }
    let thumbnail = self.solidImage(width: 30, height: 20, color: color).flatMap { self.encode($0, type: .jpeg) }
    return CardPhoto(image: image ?? Data(), thumbnail: thumbnail ?? Data())
  }

  // MARK: - 내부

  private static func makeContext(width: Int, height: Int) -> CGContext? {
    guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    return CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
  }

  private static func quadrantImage(width: Int, height: Int) -> CGImage? {
    guard let context = self.makeContext(width: width, height: height) else { return nil }
    let halfWidth = Double(width) / 2
    let halfHeight = Double(height) / 2
    // CGContext 는 원점이 왼쪽 아래라 위쪽 사분면의 y 가 halfHeight 다.
    let quadrants: [(CGRect, CGColor)] = [
      (CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight), CGColor(red: 1, green: 0, blue: 0, alpha: 1)),
      (
        CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight),
        CGColor(red: 0, green: 1, blue: 0, alpha: 1)
      ),
      (CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight), CGColor(red: 0, green: 0, blue: 1, alpha: 1)),
      (CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight), CGColor(red: 1, green: 1, blue: 0, alpha: 1)),
    ]
    for (rect, color) in quadrants {
      context.setFillColor(color)
      context.fill(rect)
    }
    return context.makeImage()
  }

  private static func solidImage(width: Int, height: Int, color: CGColor) -> CGImage? {
    guard let context = self.makeContext(width: width, height: height) else { return nil }
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  static func encode(_ image: CGImage, type: UTType, properties: CFDictionary? = nil) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }
}
