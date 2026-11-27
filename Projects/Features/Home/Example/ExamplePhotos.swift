import CoreGraphics
import DDayStoreInterface
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Example 용 사진 썸네일: 직접 그린 작은 3:2 JPEG (개인 데이터 아님).
/// Home Example 은 Photo Client 에 의존하지 않으므로 CoreGraphics·ImageIO 로 직접 만든다.
enum ExamplePhotos {
  /// sRGB 색 하나 (0~1).
  struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
      self.red = red
      self.green = green
      self.blue = blue
    }

    var cgColor: CGColor { CGColor(srgbRed: self.red, green: self.green, blue: self.blue, alpha: 1) }
  }

  /// 두 색 대각선 그라데이션 400×267 JPEG 썸네일. 만들지 못하면 빈 Data (카드는 기본 배경을 보인다).
  static func thumbnail(_ start: RGB, _ end: RGB) -> DDayPhoto {
    DDayPhoto(id: UUID(), thumbnail: self.jpeg(width: 400, height: 267, start: start, end: end))
  }

  /// 이미지가 아닌 썸네일 (손상된 썸네일 카드: 디코딩 실패 → 기본 배경).
  static let broken = DDayPhoto(id: UUID(), thumbnail: Data("not an image".utf8))

  private static func jpeg(
    width: Int,
    height: Int,
    start: RGB,
    end: RGB
  ) -> Data {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
          ),
          let gradient = CGGradient(
            colorsSpace: space,
            colors: [
              start.cgColor,
              end.cgColor,
            ] as CFArray,
            locations: [0, 1]
          )
    else {
      return Data()
    }
    context.drawLinearGradient(
      gradient,
      start: .zero,
      end: CGPoint(x: width, y: height),
      options: []
    )
    // 가운데 원 하나 (사진처럼 보이게).
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6))
    context.fillEllipse(in: CGRect(x: width / 3, y: height / 4, width: width / 3, height: height / 2))
    let data = NSMutableData()
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      return Data()
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return Data() }
    return data as Data
  }
}
