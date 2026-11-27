import CoreGraphics
import Foundation
import PhotoInterface
import PhotoTesting
import Testing
@testable import PhotoImpl

struct PhotoClientFakeTests {
  @Test("failNextLoad 는 다음 한 번만 실패시킨다")
  func failNextLoadOnce() async throws {
    let fake = PhotoClientFake()
    let picked = PhotoTest.picked(PhotoSamples.jpegData(width: 300, height: 200))
    fake.failNextLoad(with: .tooLarge)
    await #expect(throws: PhotoError.tooLarge) { try await fake.loadWorkingImage(from: picked) }
    let image = try await fake.loadWorkingImage(from: picked)
    #expect(image.width == 300)
    #expect(fake.loadCount == 2)
  }

  @Test("loadData 실패가 넣은 에러보다 먼저이고, 넣은 에러는 다음 호출에 남는다")
  func loadDataFailsFirst() async {
    let fake = PhotoClientFake()
    fake.failNextLoad(with: .decodeFailed)
    await #expect(throws: PhotoError.readFailed) { try await fake.loadWorkingImage(from: PhotoTest.failingPicked()) }
    let picked = PhotoTest.picked(PhotoSamples.jpegData(width: 300, height: 200))
    await #expect(throws: PhotoError.decodeFailed) { try await fake.loadWorkingImage(from: picked) }
  }

  @Test("이미지가 아니면 decodeFailed, 방향을 반영해 긴 변 3200 으로 읽는다")
  func loadDecodes() async throws {
    let fake = PhotoClientFake()
    await #expect(throws: PhotoError.decodeFailed) {
      try await fake.loadWorkingImage(from: PhotoTest.picked(Data("x".utf8)))
    }
    let data = PhotoSamples.jpegData(width: 4000, height: 3000, orientation: 6)
    let image = try await fake.loadWorkingImage(from: PhotoTest.picked(data))
    #expect(image.width == 2400)
    #expect(image.height == 3200)
  }

  @Test("failNextRender 는 다음 한 번만, 받은 crop 은 보정 전 값으로 기록한다")
  func failNextRenderOnce() async throws {
    let fake = PhotoClientFake()
    let image = try PhotoTest.workingImage(width: 3200, height: 2400)
    let invalid = CGRect(x: -1, y: -1, width: 5, height: 5)
    fake.failNextRender(with: .renderFailed)
    await #expect(throws: PhotoError.renderFailed) { try await fake.renderCardPhoto(from: image, crop: invalid) }
    _ = try await fake.renderCardPhoto(from: image, crop: invalid)
    #expect(fake.renderedCrops == [invalid, invalid])
  }

  @Test("성공한 render 는 Impl 과 같은 출력 크기다")
  func renderMatchesImplSizes() async throws {
    let fake = PhotoClientFake()
    let impl = PhotoClientImpl()
    let image = try PhotoTest.workingImage(width: 3200, height: 2400)
    for crop in try [
      #require(image.geometry?.defaultCrop),
      #require(image.geometry?.crop(zoom: 3, center: CGPoint(x: 0.2, y: 0.8))),
    ] {
      let fakePhoto = try await fake.renderCardPhoto(from: image, crop: crop)
      let implPhoto = try await impl.renderCardPhoto(from: image, crop: crop)
      #expect(PhotoTest.pixelSize(of: fakePhoto.image) == PhotoTest.pixelSize(of: implPhoto.image))
      #expect(PhotoTest.pixelSize(of: fakePhoto.thumbnail) == PhotoTest.pixelSize(of: implPhoto.thumbnail))
    }
  }

  @Test("지연 중인 호출이 다른 호출을 막지 않는다")
  func delayDoesNotBlock() async throws {
    let fake = PhotoClientFake(delay: .milliseconds(300))
    let data = PhotoSamples.jpegData(width: 30, height: 20)
    let clock = ContinuousClock()
    let start = clock.now
    async let first = fake.loadWorkingImage(from: PhotoTest.picked(data))
    async let second = fake.loadWorkingImage(from: PhotoTest.picked(data))
    _ = try await (first, second)
    // 둘이 잠금을 나눠 기다렸다면 600ms 이상 걸린다.
    #expect(clock.now - start < .milliseconds(590))
    #expect(fake.loadCount == 2)
  }

  @Test("샘플 카드 사진은 압축본과 썸네일이 다르고 seed 마다 다르다")
  func sampleCardPhoto() {
    let first = PhotoSamples.cardPhoto(seed: 0)
    #expect(!first.image.isEmpty && !first.thumbnail.isEmpty)
    #expect(first.image != first.thumbnail)
    #expect(PhotoSamples.cardPhoto(seed: 1) != first)
  }
}
