import Foundation
import PhotoInterface
import PhotoTesting
import Testing
import UniformTypeIdentifiers
@testable import PhotoImpl

struct PhotoClientImplLoadTests {
  private let client = PhotoClientImpl()

  @Test("방향 6 인 4000×3000 사진은 회전해 2400×3200 으로 읽는다", arguments: [UTType.jpeg, UTType.heic])
  func rotatesOrientation6(type: UTType) async throws {
    let data = PhotoSamples.imageData(width: 4000, height: 3000, orientation: 6, type: type)
    let image = try await self.client.loadWorkingImage(from: PhotoTest.picked(data))
    #expect(image.width == 2400)
    #expect(image.height == 3200)
    // 시계 방향 90° 회전: 원본 왼쪽 아래(파랑)가 왼쪽 위로 온다.
    #expect(PhotoTest.color(of: image.image, x: 0.1, y: 0.1) == .blue)
    #expect(PhotoTest.color(of: image.image, x: 0.9, y: 0.1) == .red)
  }

  @Test("방향 1 인 4000×3000 사진은 3200×2400 으로 줄인다")
  func scalesDownToMaxLongSide() async throws {
    let data = PhotoSamples.jpegData(width: 4000, height: 3000)
    let image = try await self.client.loadWorkingImage(from: PhotoTest.picked(data))
    #expect(image.width == 3200)
    #expect(image.height == 2400)
    #expect(PhotoTest.color(of: image.image, x: 0.1, y: 0.1) == .red)
  }

  @Test("작은 사진은 키우지 않는다", arguments: [(300, 200), (1, 1)])
  func doesNotUpscale(width: Int, height: Int) async throws {
    let data = PhotoSamples.jpegData(width: width, height: height)
    let image = try await self.client.loadWorkingImage(from: PhotoTest.picked(data))
    #expect(image.width == width)
    #expect(image.height == height)
  }

  @Test("이미지가 아닌 데이터·빈 데이터는 decodeFailed", arguments: [Data("not an image".utf8), Data()])
  func nonImageIsDecodeFailed(data: Data) async {
    await #expect(throws: PhotoError.decodeFailed) {
      try await self.client.loadWorkingImage(from: PhotoTest.picked(data))
    }
  }

  @Test("loadData 가 던진 readFailed 를 그대로 던진다")
  func readFailedPassesThrough() async {
    await #expect(throws: PhotoError.readFailed) {
      try await self.client.loadWorkingImage(from: PhotoTest.failingPicked())
    }
  }

  @Test("바이트 한도를 넘으면 tooLarge")
  func byteLimit() async {
    let client = PhotoClientImpl(limits: PhotoInputLimits(maxByteCount: 100, maxPixelCount: 100_000_000))
    let data = PhotoSamples.jpegData(width: 300, height: 200)
    await #expect(throws: PhotoError.tooLarge) {
      try await client.loadWorkingImage(from: PhotoTest.picked(data))
    }
  }

  @Test("픽셀 한도를 넘으면 디코딩 전에 tooLarge")
  func pixelLimit() async {
    let client = PhotoClientImpl(limits: PhotoInputLimits(
      maxByteCount: 100 * 1024 * 1024,
      maxPixelCount: 300 * 200 - 1
    ))
    let data = PhotoSamples.jpegData(width: 300, height: 200)
    await #expect(throws: PhotoError.tooLarge) {
      try await client.loadWorkingImage(from: PhotoTest.picked(data))
    }
  }

  @Test("취소된 Task 에서 부르면 readFailed")
  func cancelledTaskIsReadFailed() async {
    let data = PhotoSamples.jpegData(width: 300, height: 200)
    let client = self.client
    // 취소될 때까지 읽기를 끝내지 않아, 읽기 뒤의 취소 확인이 반드시 취소를 본다.
    let picked = PickedPhoto {
      while !Task.isCancelled {
        await Task.yield()
      }
      return data
    }
    let task = Task { try await client.loadWorkingImage(from: picked) }
    task.cancel()
    let result = await task.result
    #expect(throws: PhotoError.readFailed) { try result.get() }
  }
}
