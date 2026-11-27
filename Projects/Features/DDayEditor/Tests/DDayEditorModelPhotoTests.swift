import Core
import CoreGraphics
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import PhotoInterface
import PhotoTesting
import Testing
@testable import DDayEditorFeature

/// 사진 이벤트를 Fake(저장소·사진 클라이언트)로 끝까지 돌린다 (설계 §6.5 1~13).
@MainActor
struct DDayEditorModelPhotoTests {
  let recorder = OutcomeRecorder()

  /// 사진을 골라 자르기 화면까지 간다.
  func pickToCropping(_ model: DDayEditorModel) async throws -> PhotoWorkingImage {
    await model.photoPicked(EditorSample.pickedJPEG)?.value
    return try #require(model.cropImage)
  }

  /// 사진을 골라 기본 영역으로 만들기까지 마치고 만든 사진을 돌려준다.
  func pickAndRender(_ model: DDayEditorModel) async throws -> CardPhoto {
    let image = try await self.pickToCropping(model)
    let geometry = try #require(image.geometry)
    await model.cropConfirmed(geometry.defaultCrop)?.value
    return try #require(model.photo.newPhoto)
  }

  // 1
  @Test("처음 사진: 추가는 없음, 수정은 저장된 사진. 사진 변경은 keep 이고 변경 없음")
  func initialPhotoState() {
    let added = makeEditor(.add)
    #expect(added.photo == .none)
    #expect(added.photoStep == .idle)
    #expect(added.photoNotice == nil)
    #expect(added.draft.photo == .keep)
    #expect(!added.hasChanges)

    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let edited = makeEditor(.edit(stored), store: EditorSample.photoFake(stored))
    #expect(edited.photo == .stored(EditorSample.storedPhoto))
    #expect(edited.photoPreviewThumbnail == EditorSample.storedPhoto.thumbnail)
    #expect(edited.draft.photo == .keep)
    #expect(!edited.hasChanges)
  }

  // 2
  @Test("사진을 고르면 같은 차례에 불러오는 중이 되고, 끝나면 자르기 화면이다")
  func photoPickedLoadsThenCrops() async throws {
    let model = makeEditor(.add)

    let task = model.photoPicked(EditorSample.pickedJPEG)

    #expect(task != nil)
    #expect(model.photoStep == .loading)
    #expect(model.isPhotoBusy)
    #expect(!model.canPickPhoto)
    await task?.value
    let image = try #require(model.cropImage)
    #expect(model.photoStep == .cropping(image))
    #expect(image.width == 400)
    #expect(image.height == 300)
    #expect(model.isCropPresented)
    #expect(model.photo == .none)
  }

  // 3
  @Test("고른 사진을 읽지 못하면 안내를 띄우고 저장된 사진을 그대로 둔다")
  func readFailureKeepsStoredPhoto() async {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let model = makeEditor(.edit(stored), store: EditorSample.photoFake(stored))

    await model.photoPicked(EditorSample.unreadable)?.value

    #expect(model.photoStep == .idle)
    #expect(model.photoNotice == .loadFailed)
    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(!model.hasChanges)
  }

  // 4
  @Test(
    "불러오기 실패 종류에 맞는 안내",
    arguments: [
      (PhotoError.decodeFailed, DDayEditorModel.PhotoNotice.loadFailed),
      (.readFailed, .loadFailed),
      (.renderFailed, .loadFailed),
      (.tooLarge, .tooLarge),
    ]
  )
  func loadFailureNotice(error: PhotoError, notice: DDayEditorModel.PhotoNotice) async {
    let photoClient = PhotoClientFake()
    photoClient.failNextLoad(with: error)
    let model = makeEditor(.add, photoClient: photoClient)

    await model.photoPicked(EditorSample.pickedJPEG)?.value

    #expect(model.photoStep == .idle)
    #expect(model.photoNotice == notice)
    #expect(model.photo == .none)
  }

  // 5
  @Test("자르기 [완료] 가 성공하면 새 사진이 되고 저장할 변경은 replace 다")
  func cropConfirmedMakesNewPhoto() async throws {
    let model = makeEditor(.add)
    let image = try await self.pickToCropping(model)
    let geometry = try #require(image.geometry)

    let task = model.cropConfirmed(geometry.defaultCrop)

    #expect(model.photoStep == .rendering(image))
    #expect(model.isRendering)
    #expect(model.isCropPresented)
    await task?.value
    guard case let .new(cardPhoto) = model.photo else {
      Issue.record("새 사진이 아니다: \(model.photo)")
      return
    }
    #expect(model.photoStep == .idle)
    #expect(!model.isCropPresented)
    #expect(model.photoPreviewThumbnail == cardPhoto.thumbnail)
    #expect(model.draft.photo == .replace(cardPhoto))
    #expect(model.hasChanges)
  }

  // 6
  @Test(
    "자르기 영역은 클램프한 값으로 넘긴다 (범위 밖·NaN)",
    arguments: [
      CGRect(x: -3, y: 5, width: 9, height: 0.1),
      CGRect(x: CGFloat.nan, y: 0, width: 0.5, height: 0.5),
      CGRect(x: 0.9, y: 0.9, width: 0.2, height: 0.2),
    ]
  )
  func cropIsClampedBeforeRender(crop: CGRect) async throws {
    let photoClient = PhotoClientFake()
    let model = makeEditor(.add, photoClient: photoClient)
    let image = try await self.pickToCropping(model)
    let geometry = try #require(image.geometry)

    await model.cropConfirmed(crop)?.value

    #expect(photoClient.renderedCrops == [geometry.clamped(crop)])
    guard case .new = model.photo else {
      Issue.record("새 사진이 아니다: \(model.photo)")
      return
    }
  }

  // 7
  @Test("만들기에 실패하면 자르기 화면에 남아 안내하고, 다시 [완료] 하면 성공한다")
  func renderFailureStaysInCropping() async throws {
    let photoClient = PhotoClientFake()
    let model = makeEditor(.add, photoClient: photoClient)
    let image = try await self.pickToCropping(model)
    let geometry = try #require(image.geometry)
    photoClient.failNextRender(with: .renderFailed)

    await model.cropConfirmed(geometry.defaultCrop)?.value

    #expect(model.photoStep == .cropping(image))
    #expect(model.photoNotice == .renderFailed)
    #expect(model.photo == .none)

    await model.cropConfirmed(geometry.defaultCrop)?.value

    #expect(model.photoNotice == nil)
    #expect(model.photoStep == .idle)
    guard case .new = model.photo else {
      Issue.record("새 사진이 아니다: \(model.photo)")
      return
    }
  }

  // 8
  @Test("자르기 [취소] 는 기존 사진을 그대로 두고 안내를 지운다")
  func cropCancelledKeepsPhoto() async throws {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let photoClient = PhotoClientFake()
    let model = makeEditor(.edit(stored), store: EditorSample.photoFake(stored), photoClient: photoClient)
    let image = try await self.pickToCropping(model)
    photoClient.failNextRender(with: .renderFailed)
    try await model.cropConfirmed(#require(image.geometry).defaultCrop)?.value
    #expect(model.photoNotice == .renderFailed)

    model.cropCancelled()

    #expect(model.photoStep == .idle)
    #expect(model.photoNotice == nil)
    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(!model.hasChanges)
  }

  // 9
  @Test("사진 지우기: 저장된 사진이면 remove, 추가 모드에서 만든 사진이면 다시 변경 없음")
  func photoRemoveTapped() async throws {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let edited = makeEditor(.edit(stored), store: EditorSample.photoFake(stored))
    edited.photoRemoveTapped()
    #expect(edited.photo == .none)
    #expect(edited.draft.photo == .remove)
    #expect(edited.hasChanges)

    let added = makeEditor(.add)
    _ = try await self.pickAndRender(added)
    #expect(added.hasChanges)
    added.photoRemoveTapped()
    #expect(added.photo == .none)
    #expect(added.draft.photo == .keep)
    #expect(!added.hasChanges)
  }
}
