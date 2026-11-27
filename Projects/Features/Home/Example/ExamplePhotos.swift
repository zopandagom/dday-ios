import Core
import CoreGraphics
import DDayStoreInterface
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Example 용 사진: 직접 그린 3:2 JPEG 두 벌(압축본 1600×1067·썸네일 400×267, 개인 데이터 아님).
/// Home Example 은 Photo Client 에 의존하지 않으므로 CoreGraphics·ImageIO 로 직접 만든다.
///
/// 선명도 비교용으로 그림에 가는 세로 줄무늬(1600px 기준 1px 선·4px 주기)를 넣는다. 썸네일은 같은 그림을 1600×1067 로
/// 그린 뒤 400×267 로 축소해 만든다(실제 앱처럼 같은 원본의 축소본). 그래서 썸네일에서는 줄무늬가 회색 면으로 뭉개지고,
/// 상세의 압축본에서는 줄이 하나하나 보인다.
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

  /// 저장된 사진 하나: 목록용 사진(썸네일·사진 id)과 압축본 JPEG (Fake 의 `photoImages` 에 넣는다).
  struct Sample {
    let photo: DDayPhoto
    let image: Data
  }

  /// 두 색 그림의 저장된 사진 (새 사진 id).
  static func sample(_ start: RGB, _ end: RGB) -> Sample {
    let cardPhoto = self.cardPhoto(start, end)
    return Sample(photo: DDayPhoto(id: UUID(), thumbnail: cardPhoto.thumbnail), image: cardPhoto.image)
  }

  /// 두 색 그림의 카드 사진 (압축본 1600×1067 + 그 축소본 썸네일 400×267). 만들지 못한 쪽은 빈 Data
  /// (썸네일이 비면 카드는 기본 배경, 압축본이 비면 상세는 썸네일을 보인다).
  static func cardPhoto(_ start: RGB, _ end: RGB) -> CardPhoto {
    guard let full = self.drawing(start: start, end: end) else {
      return CardPhoto(image: Data(), thumbnail: Data())
    }
    let thumbnail = self.downscaled(full, width: Self.thumbnailWidth, height: Self.thumbnailHeight)
    return CardPhoto(image: self.jpeg(full), thumbnail: thumbnail.map(self.jpeg) ?? Data())
  }

  /// 이미지가 아닌 썸네일·압축본 (손상된 사진 카드: 디코딩 실패 → 카드·상세 모두 기본 배경).
  static let broken = Sample(
    photo: DDayPhoto(id: UUID(), thumbnail: Data("not an image".utf8)),
    image: Data("not an image".utf8)
  )

  // MARK: - Private

  private static let imageWidth = PhotoCropGeometry.imageMaxLongSide // 1600
  private static let imageHeight = 1067
  private static let thumbnailWidth = PhotoCropGeometry.thumbnailMaxLongSide // 400
  private static let thumbnailHeight = 267

  /// 그림을 1600×1067 로 그린다. 위치는 정규화 좌표(0~1, 위가 0)로 정의한다.
  private static func drawing(start: RGB, end: RGB) -> CGImage? {
    let width = self.imageWidth
    let height = self.imageHeight
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = self.context(width: width, height: height, space: space),
          let gradient = CGGradient(
            colorsSpace: space,
            colors: [
              start.cgColor,
              end.cgColor,
            ] as CFArray,
            locations: [0, 1]
          )
    else {
      return nil
    }
    let size = CGSize(width: width, height: height)
    // CGContext 는 원점이 왼쪽 아래라 위가 0 인 정규화 좌표를 뒤집어 넣는다.
    func rect(x: Double, y: Double, width: Double, height: Double) -> CGRect {
      CGRect(
        x: x * size.width,
        y: (1 - y - height) * size.height,
        width: width * size.width,
        height: height * size.height
      )
    }
    // 대각선 그라데이션.
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
    // 가운데 원 (x 1/3~2/3, y 1/4~3/4, 흰색 60%).
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6))
    context.fillEllipse(in: rect(x: 1.0 / 3, y: 1.0 / 4, width: 1.0 / 3, height: 1.0 / 2))
    // 줄무늬 영역 (x 0.05~0.45, y 0.08~0.30): 세로 흰 선, 선 폭 1/1600, 간격 4/1600, 불투명.
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    let lineWidth = 1.0 / 1600
    let period = 4.0 / 1600
    // 1600px 에서 선이 픽셀 경계에 딱 맞으므로 안티앨리어싱을 꺼 1px 선이 번지지 않게 한다.
    context.setShouldAntialias(false)
    let lineCount = Int(((0.45 - 0.05) / period).rounded(.down))
    for index in 0 ..< lineCount {
      context.fill(rect(x: 0.05 + Double(index) * period, y: 0.08, width: lineWidth, height: 0.22))
    }
    return context.makeImage()
  }

  /// 그린 그림을 작은 크기로 다시 그려 축소한다 (`interpolationQuality = .high`).
  private static func downscaled(_ image: CGImage, width: Int, height: Int) -> CGImage? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = self.context(width: width, height: height, space: space)
    else {
      return nil
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
  }

  private static func context(width: Int, height: Int, space: CGColorSpace) -> CGContext? {
    CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: space,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
  }

  /// JPEG 품질 0.8. 만들지 못하면 빈 Data.
  private static func jpeg(_ image: CGImage) -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
      return Data()
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return Data() }
    return data as Data
  }
}
