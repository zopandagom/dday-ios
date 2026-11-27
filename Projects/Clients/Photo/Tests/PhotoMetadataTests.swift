import Foundation
import ImageIO
import PhotoInterface
import PhotoTesting
import Testing
import UniformTypeIdentifiers
@testable import PhotoImpl

/// 만든 JPEG 에 원본 메타데이터(위치·기기·촬영 정보·방향)가 남지 않는지 (PRODUCT §1 기기 밖으로 정보를 내보내지 않음).
struct PhotoMetadataTests {
  /// ImageIO 가 인코딩 때 스스로 넣는 EXIF 키.
  private static let allowedExifKeys: Set<String> = [
    kCGImagePropertyExifColorSpace as String,
    kCGImagePropertyExifPixelXDimension as String,
    kCGImagePropertyExifPixelYDimension as String,
  ]
  private static let allowedXMPTags: Set<String> = ["exif:ColorSpace", "exif:PixelXDimension", "exif:PixelYDimension"]
  private static let privateValues = ["2024:05:01 10:20:30", "Sample Lens 1.0", "SampleMaker", "SampleModel X"]

  @Test("원본의 EXIF·GPS·TIFF·방향이 압축본·썸네일에 남지 않는다", arguments: [UTType.jpeg, UTType.heic])
  func stripsMetadata(type: UTType) async throws {
    let data = PhotoSamples.imageData(
      width: 4000,
      height: 3000,
      orientation: 6,
      includesPrivateMetadata: true,
      type: type
    )
    // 입력에는 실제로 메타데이터가 들어 있다 (테스트 전제).
    let input = PhotoTest.properties(of: data)
    #expect(input[kCGImagePropertyGPSDictionary as String] != nil)
    #expect(input[kCGImagePropertyTIFFDictionary as String] != nil)

    let client = PhotoClientImpl()
    let image = try await client.loadWorkingImage(from: PhotoTest.picked(data))
    let photo = try await client.renderCardPhoto(from: image, crop: #require(image.geometry?.defaultCrop))

    for output in [photo.image, photo.thumbnail] {
      let properties = PhotoTest.properties(of: output)
      #expect(properties[kCGImagePropertyGPSDictionary as String] == nil)
      #expect(properties[kCGImagePropertyTIFFDictionary as String] == nil)
      #expect(properties[kCGImagePropertyOrientation as String] == nil)
      let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
      #expect(Set(exif.keys).isSubset(of: Self.allowedExifKeys))
      #expect(PhotoTest.xmpTagNames(of: output).isSubset(of: Self.allowedXMPTags))
      let bytes = String(bytes: output, encoding: .isoLatin1) ?? ""
      for value in Self.privateValues {
        #expect(!bytes.contains(value))
      }
      // 픽셀은 회전된 방향(세로 작업 이미지에서 자른 3:2)이고 왼쪽 위는 원본 왼쪽 아래 색이다.
      #expect(PhotoTest.color(of: output, x: 0.05, y: 0.05) == .blue)
    }
  }
}
