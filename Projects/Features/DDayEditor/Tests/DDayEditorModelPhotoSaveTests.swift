import Core
import CoreGraphics
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import PhotoInterface
import PhotoTesting
import Testing
@testable import DDayEditorFeature

/// 사진을 넣은 저장 (설계 §6.5 1~13 중 저장 경우). 도우미는 `DDayEditorModelPhotoTests` 에 있다.
extension DDayEditorModelPhotoTests {
  // 10
  @Test("새 사진으로 저장하면 저장소에 썸네일·압축본이 들어가고 결과에 사진이 있다")
  func saveWithNewPhoto() async throws {
    let fake = DDayStoreClientFake()
    let model = makeEditor(.add, store: fake, recorder: self.recorder)
    model.titleChanged("여행")
    let cardPhoto = try await self.pickAndRender(model)

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    let photo = try #require(saved.photo)
    #expect(photo.thumbnail == cardPhoto.thumbnail)
    #expect(fake.photoImages[saved.id] == cardPhoto.image)
    #expect(try await fake.fetchPhoto(id: saved.id) == cardPhoto.image)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("저장된 사진을 지우고 저장하면 저장소에 사진이 없다")
  func saveWithRemovedPhoto() async throws {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let fake = EditorSample.photoFake(stored)
    let model = makeEditor(.edit(stored), store: fake, recorder: self.recorder)
    model.photoRemoveTapped()

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.photo == nil)
    #expect(try await fake.fetchPhoto(id: saved.id) == nil)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  // 11
  @Test("저장에 실패해도 새 사진은 그대로이고 다시 저장하면 성공한다")
  func saveFailureKeepsNewPhoto() async throws {
    let fake = DDayStoreClientFake()
    let model = makeEditor(.add, store: fake, recorder: self.recorder)
    model.titleChanged("여행")
    let cardPhoto = try await self.pickAndRender(model)
    fake.failNextCall(with: .saveFailed)

    await model.saveButtonTapped()?.value

    #expect(model.alert == .saveFailed)
    #expect(model.photo == .new(cardPhoto))
    #expect(fake.dDays.isEmpty)
    model.alertDismissed()

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.photo?.thumbnail == cardPhoto.thumbnail)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  // 12
  @Test("수정 저장이 notFound 면 저장된 사진을 잃고, 새로 저장은 사진 없이 추가한다")
  func notFoundLosesStoredPhoto() async throws {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let fake = DDayStoreClientFake()
    let model = makeEditor(.edit(stored), store: fake, recorder: self.recorder)
    model.titleChanged("바뀐 제목")

    await model.saveButtonTapped()?.value

    #expect(model.alert == .notFoundOnSave)
    #expect(model.photo == .none)
    #expect(model.isStoredPhotoLost)
    #expect(model.isPhotoLostMessageShown)

    await model.saveAsNewTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.photo == nil)
    #expect(fake.photoImages.isEmpty)
    #expect(self.recorder.outcomes == [.savedAsNew(saved, replacing: EditorSample.originalID)])
  }

  @Test("수정 저장이 notFound 여도 새로 고른 사진은 남아 새로 저장에 들어간다")
  func notFoundKeepsNewPhoto() async throws {
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let fake = DDayStoreClientFake()
    let model = makeEditor(.edit(stored), store: fake, recorder: self.recorder)
    let cardPhoto = try await self.pickAndRender(model)

    await model.saveButtonTapped()?.value

    #expect(model.alert == .notFoundOnSave)
    #expect(model.photo == .new(cardPhoto))
    #expect(!model.isStoredPhotoLost)
    #expect(!model.isPhotoLostMessageShown)

    await model.saveAsNewTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.photo?.thumbnail == cardPhoto.thumbnail)
    #expect(fake.photoImages[saved.id] == cardPhoto.image)
  }

  // 13
  @Test("안내는 다음 사진 고르기와 사진 지우기가 지운다")
  func noticeClearedByNextPickOrRemove() async {
    let photoClient = PhotoClientFake()
    let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)
    let model = makeEditor(.edit(stored), store: EditorSample.photoFake(stored), photoClient: photoClient)
    photoClient.failNextLoad(with: .tooLarge)
    await model.photoPicked(EditorSample.pickedJPEG)?.value
    #expect(model.photoNotice == .tooLarge)

    let task = model.photoPicked(EditorSample.pickedJPEG)
    #expect(model.photoNotice == nil)
    await task?.value
    model.cropCancelled()

    photoClient.failNextLoad(with: .decodeFailed)
    await model.photoPicked(EditorSample.pickedJPEG)?.value
    #expect(model.photoNotice == .loadFailed)

    model.photoRemoveTapped()
    #expect(model.photoNotice == nil)
    #expect(model.photo == .none)
  }
}
