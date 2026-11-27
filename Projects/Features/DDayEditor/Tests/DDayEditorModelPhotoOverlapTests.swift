import Core
import CoreGraphics
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import PhotoInterface
import PhotoTesting
import Testing
@testable import DDayEditorFeature

/// 사진 처리 await 중에 오는 이벤트 (설계 §6.3, §6.5 14~24). 시작한 호출은 모두 resume 한다.
@MainActor
struct DDayEditorModelPhotoOverlapTests {
  let recorder = OutcomeRecorder()
  let photoClient = ControlledPhotoClient()
  let store = ControlledEditorStore()
  let stored = EditorSample.dDay(photo: EditorSample.storedPhoto)

  /// 저장된 사진이 있는 수정 모델 (Controlled 저장소·사진 클라이언트).
  func makeModel() -> DDayEditorModel {
    makeEditor(.edit(self.stored), store: self.store, photoClient: self.photoClient, recorder: self.recorder)
  }

  /// 불러오기를 시작하고 클라이언트에서 멈출 때까지 기다린다.
  func startLoading(_ model: DDayEditorModel) async throws -> Task<Void, Never>? {
    let task = model.photoPicked(EditorSample.anyPicked)
    try await self.photoClient.waitForPendingLoad()
    return task
  }

  /// 자르기 화면까지 간다.
  func toCropping(_ model: DDayEditorModel, image: PhotoWorkingImage) async throws {
    let task = try await self.startLoading(model)
    try self.photoClient.resumeLoad(with: .success(image))
    await task?.value
    #expect(model.photoStep == .cropping(image))
  }

  /// 만들기를 시작하고 클라이언트에서 멈출 때까지 기다린다.
  func startRendering(_ model: DDayEditorModel, image: PhotoWorkingImage) async throws -> Task<Void, Never>? {
    try await self.toCropping(model, image: image)
    let task = try model.cropConfirmed(#require(image.geometry).defaultCrop)
    try await self.photoClient.waitForPendingRender()
    #expect(model.photoStep == .rendering(image))
    return task
  }

  // 14
  @Test("불러오는 중에는 다시 고르기·저장·새로 저장·삭제·사진 지우기를 무시하고 끌어내리기를 막는다")
  func whileLoadingOtherEventsIgnored() async throws {
    let model = self.makeModel()
    let task = try await self.startLoading(model)

    #expect(model.photoPicked(EditorSample.anyPicked) == nil)
    #expect(model.saveButtonTapped() == nil)
    #expect(model.saveAsNewTapped() == nil)
    model.deleteButtonTapped()
    model.photoRemoveTapped()

    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(model.isDismissDisabled)
    #expect(!model.canPickPhoto)
    #expect(!model.canSave)
    #expect(self.store.calls.isEmpty)
    #expect(self.photoClient.loadCallCount == 1)

    let image = EditorSample.workingImage()
    try self.photoClient.resumeLoad(with: .success(image))
    await task?.value
    #expect(model.photoStep == .cropping(image))
  }

  // 15
  @Test("불러오기 [취소] 뒤 늦게 온 성공·실패는 상태를 바꾸지 않는다", arguments: [true, false])
  func lateResultAfterLoadingCancelledIgnored(succeeds: Bool) async throws {
    let model = self.makeModel()
    let task = try await self.startLoading(model)

    model.photoLoadingCancelled()

    #expect(model.photoStep == .idle)
    #expect(model.canPickPhoto)
    try self.photoClient.resumeLoad(with: succeeds ? .success(EditorSample.workingImage()) : .failure(.tooLarge))
    await task?.value
    #expect(model.photoStep == .idle)
    #expect(model.photoNotice == nil)
    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(self.photoClient.cancelledLoadCount == 1)
  }

  // 16
  @Test("불러오는 중 [취소]·시트 닫기는 한 번 닫고 늦은 결과를 버린다", arguments: [true, false])
  func closingWhileLoading(byCancelButton: Bool) async throws {
    let model = self.makeModel()
    let task = try await self.startLoading(model)

    if byCancelButton {
      model.cancelButtonTapped()
    } else {
      model.sheetDismissed()
    }

    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.phase == .finished)
    #expect(self.photoClient.cancelledLoadCount == 1)
    try self.photoClient.resumeLoad(with: .success(EditorSample.workingImage()))
    await task?.value
    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.phase == .finished)
    #expect(model.photoStep == .loading)
  }

  // 17
  @Test("만드는 중에는 자르기 [취소]·[완료]·저장을 무시한다")
  func whileRenderingEventsIgnored() async throws {
    let model = self.makeModel()
    let image = EditorSample.workingImage()
    let task = try await self.startRendering(model, image: image)

    model.cropCancelled()
    #expect(try model.cropConfirmed(#require(image.geometry).defaultCrop) == nil)
    #expect(model.saveButtonTapped() == nil)
    model.photoRemoveTapped()

    #expect(model.photoStep == .rendering(image))
    #expect(model.isRendering)
    #expect(model.isDismissDisabled)
    #expect(self.photoClient.renderedCrops.count == 1)
    #expect(self.store.calls.isEmpty)

    let cardPhoto = EditorSample.cardPhoto()
    try self.photoClient.resumeRender(with: .success(cardPhoto))
    await task?.value
    #expect(model.photo == .new(cardPhoto))
    #expect(model.photoStep == .idle)
  }

  // 18
  @Test("저장 중에는 사진 고르기·지우기·자르기 [완료] 를 무시한다")
  func whileSavingPhotoEventsIgnored() async throws {
    let model = self.makeModel()
    let saveTask = model.saveButtonTapped()
    #expect(model.phase == .saving)

    #expect(model.photoPicked(EditorSample.anyPicked) == nil)
    model.photoRemoveTapped()
    #expect(model.cropConfirmed(CGRect(x: 0, y: 0, width: 1, height: 1)) == nil)

    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(model.photoStep == .idle)
    #expect(self.photoClient.loadCallCount == 0)

    try await self.store.waitForPendingWrite()
    try self.store.resumeWrite(with: .success(self.stored))
    await saveTask?.value
    #expect(self.store.calls == [.update(EditorSample.originalID, self.stored.draft)])
  }

  // 19
  @Test("자르기 [완료] 는 자르기 중이 아니면 nil 이다 (처음·불러오는 중)")
  func cropConfirmedOnlyWhileCropping() async throws {
    let model = self.makeModel()
    let crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    #expect(model.cropConfirmed(crop) == nil)

    let task = try await self.startLoading(model)
    #expect(model.cropConfirmed(crop) == nil)
    #expect(model.photoStep == .loading)

    try self.photoClient.resumeLoad(with: .failure(.decodeFailed))
    await task?.value
    #expect(model.cropConfirmed(crop) == nil)
    #expect(self.photoClient.renderedCrops.isEmpty)
  }

  // 20
  @Test("불러오는 중 삭제 확인은 확인창 없이 바로 불러도 무시한다")
  func deleteConfirmedWhileLoadingIgnored() async throws {
    let model = self.makeModel()
    let task = try await self.startLoading(model)

    #expect(model.deleteConfirmed() == nil)

    #expect(self.store.calls.isEmpty)
    #expect(model.phase == .editing)
    try self.photoClient.resumeLoad(with: .failure(.readFailed))
    await task?.value
    #expect(model.photoStep == .idle)
    #expect(model.photoNotice == .loadFailed)
  }

  enum CloseWhileRendering: CaseIterable {
    case sheetDismissed
    case cancelWithoutChanges
    case cancelWithChangesThenDiscard
  }

  // 21
  @Test("만드는 중 닫으면 결과는 한 번이고 늦게 온 사진은 반영하지 않는다", arguments: CloseWhileRendering.allCases)
  func closingWhileRendering(close: CloseWhileRendering) async throws {
    let model = self.makeModel()
    if close == .cancelWithChangesThenDiscard {
      model.titleChanged("바뀐 제목")
    }
    let task = try await self.startRendering(model, image: EditorSample.workingImage())

    switch close {
    case .sheetDismissed:
      model.sheetDismissed()
    case .cancelWithoutChanges:
      model.cancelButtonTapped()
    case .cancelWithChangesThenDiscard:
      model.cancelButtonTapped()
      #expect(model.isDiscardConfirmationPresented)
      #expect(!model.isCropPresented)
      #expect(self.recorder.outcomes.isEmpty)
      // 확인창 때문에 자르기 화면이 내려가며 오는 바인딩 set(false) 는 무시한다.
      model.cropCancelled()
      #expect(model.isRendering)
      model.discardConfirmed()
    }

    #expect(self.recorder.outcomes == [.cancelled])
    try self.photoClient.resumeRender(with: .success(EditorSample.cardPhoto()))
    await task?.value
    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.photo == .stored(EditorSample.storedPhoto))
    #expect(model.phase == .finished)
  }

  // 22
  @Test("불러오기 [취소] 뒤 바로 다시 고를 수 있고, 옛 요청은 취소되며 그 결과는 새 요청을 바꾸지 않는다")
  func pickAgainAfterLoadingCancelled() async throws {
    let model = self.makeModel()
    let oldTask = try await self.startLoading(model)
    model.photoLoadingCancelled()

    let newTask = model.photoPicked(EditorSample.anyPicked)

    #expect(newTask != nil)
    #expect(model.photoStep == .loading)
    try await self.photoClient.waitForPendingLoad(2)
    #expect(self.photoClient.cancelledLoadCount == 1)

    // 먼저 멈춘 옛 요청을 끝낸다.
    try self.photoClient.resumeLoad(with: .success(EditorSample.workingImage(width: 10, height: 10)))
    await oldTask?.value
    #expect(model.photoStep == .loading)

    let image = EditorSample.workingImage()
    try self.photoClient.resumeLoad(with: .success(image))
    await newTask?.value
    #expect(model.photoStep == .cropping(image))
    #expect(self.photoClient.cancelledLoadCount == 1)
  }

  // 23
  @Test("버리기 확인창이 떠 있는 동안 불러오기가 끝나면 자르기 화면을 미룬다", arguments: [true, false])
  func loadFinishesWhileDiscardConfirmation(keepsEditing: Bool) async throws {
    let model = self.makeModel()
    model.titleChanged("바뀐 제목")
    let task = try await self.startLoading(model)
    model.cancelButtonTapped()
    #expect(model.isDiscardConfirmationPresented)

    let image = EditorSample.workingImage()
    try self.photoClient.resumeLoad(with: .success(image))
    await task?.value

    #expect(model.photoStep == .cropping(image))
    #expect(!model.isCropPresented)
    // 확인창이 떠 있는 동안의 자르기 [취소](바인딩 set(false))는 작업 이미지를 버리지 않는다.
    model.cropCancelled()
    #expect(model.photoStep == .cropping(image))

    if keepsEditing {
      model.discardConfirmationDismissed()
      #expect(model.isCropPresented)
      #expect(self.recorder.outcomes.isEmpty)
    } else {
      model.discardConfirmed()
      #expect(self.recorder.outcomes == [.cancelled])
      #expect(model.phase == .finished)
    }
  }

  // 24
  @Test("notFound 로 저장된 사진을 잃을 때만 사진 문구를 쓴다")
  func storedPhotoLostOnlyForStoredPhoto() async throws {
    // 저장된 사진을 잃는다.
    let lost = makeEditor(.edit(self.stored), store: DDayStoreClientFake(), photoClient: PhotoClientFake())
    await lost.saveButtonTapped()?.value
    #expect(lost.isStoredPhotoLost)
    #expect(lost.isPhotoLostMessageShown)
    #expect(lost.photo == .none)

    // 잃은 뒤 새 사진을 고르고 다시 notFound: 사진 문구가 아니다.
    lost.alertDismissed()
    await lost.photoPicked(EditorSample.pickedJPEG)?.value
    try await lost.cropConfirmed(#require(lost.cropImage?.geometry).defaultCrop)?.value
    #expect(lost.photo.newPhoto != nil)
    await lost.saveButtonTapped()?.value
    #expect(lost.alert == .notFoundOnSave)
    #expect(lost.isStoredPhotoLost)
    #expect(!lost.isPhotoLostMessageShown)

    // 원래 사진이 없으면 잃을 것이 없다.
    let noPhoto = makeEditor(.edit(EditorSample.dDay()), store: DDayStoreClientFake())
    await noPhoto.saveButtonTapped()?.value
    #expect(noPhoto.alert == .notFoundOnSave)
    #expect(!noPhoto.isStoredPhotoLost)
    #expect(!noPhoto.isPhotoLostMessageShown)
  }
}
