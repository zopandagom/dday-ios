import PhotoInterface

/// 고른 사진의 입력 한도. 48MP ProRAW·아이폰 파노라마는 받고, 축소 디코딩이 안 되는 형식(PNG 등)이
/// 원본 전체를 디코딩할 때의 순간 메모리를 1억 화소(약 400MB)로 막는다.
struct PhotoInputLimits: Sendable {
  var maxByteCount: Int
  var maxPixelCount: Int

  static let `default` = PhotoInputLimits(maxByteCount: 100 * 1024 * 1024, maxPixelCount: 100_000_000)

  /// 바이트 한도. 경계값은 허용(초과만 `.tooLarge`).
  func check(byteCount: Int) -> PhotoError? {
    byteCount > self.maxByteCount ? .tooLarge : nil
  }

  /// 픽셀 한도. 폭·높이 ≤ 0 은 `.decodeFailed`, 경계값은 허용(초과만 `.tooLarge`). 곱이 Int 를 넘쳐도 `.tooLarge`.
  func check(pixelWidth: Int, pixelHeight: Int) -> PhotoError? {
    guard pixelWidth > 0, pixelHeight > 0 else { return .decodeFailed }
    let (pixelCount, overflow) = pixelWidth.multipliedReportingOverflow(by: pixelHeight)
    return overflow || pixelCount > self.maxPixelCount ? .tooLarge : nil
  }
}
