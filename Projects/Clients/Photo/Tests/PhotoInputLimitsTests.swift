import PhotoInterface
import Testing
@testable import PhotoImpl

struct PhotoInputLimitsTests {
  private let limits = PhotoInputLimits(maxByteCount: 1000, maxPixelCount: 10000)

  @Test("기본 한도는 100MiB·1억 화소")
  func defaultLimits() {
    #expect(PhotoInputLimits.default.maxByteCount == 100 * 1024 * 1024)
    #expect(PhotoInputLimits.default.maxPixelCount == 100_000_000)
  }

  @Test("바이트: 한도 이하는 통과, 초과만 tooLarge", arguments: [(999, nil), (1000, nil), (1001, PhotoError.tooLarge)])
  func byteCount(count: Int, expected: PhotoError?) {
    #expect(self.limits.check(byteCount: count) == expected)
  }

  @Test(
    "픽셀: 한도 이하는 통과, 초과만 tooLarge",
    arguments: [(100, 100, nil), (10000, 1, nil), (101, 100, PhotoError.tooLarge), (10001, 1, PhotoError.tooLarge)]
  )
  func pixelCount(width: Int, height: Int, expected: PhotoError?) {
    #expect(self.limits.check(pixelWidth: width, pixelHeight: height) == expected)
  }

  @Test("픽셀: 폭·높이 0 이나 음수는 decodeFailed", arguments: [(0, 10), (10, 0), (-1, 10), (10, -1)])
  func invalidPixelSize(width: Int, height: Int) {
    #expect(self.limits.check(pixelWidth: width, pixelHeight: height) == .decodeFailed)
  }

  @Test("픽셀: 곱이 Int 를 넘치는 크기도 넘침 없이 tooLarge")
  func overflowingPixelSize() {
    #expect(self.limits.check(pixelWidth: Int.max, pixelHeight: 2) == .tooLarge)
    #expect(PhotoInputLimits.default.check(pixelWidth: Int.max / 2, pixelHeight: Int.max / 2) == .tooLarge)
  }
}
