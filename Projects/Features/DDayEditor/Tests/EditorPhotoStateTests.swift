import Core
import CoreGraphics
import Foundation
import PhotoInterface
import Testing
@testable import DDayEditorFeature

/// 사진 상태 전이 규칙 (`EditorPhotoState.apply(_:)`). 단계마다 받을 수 있는 전이와, 요청 id 가 지금 요청일 때만
/// 결과를 받는지 본다.
struct EditorPhotoStateTests {
  let image = EditorSample.workingImage()

  /// 불러오기를 마쳐 자르기 중인 상태.
  func cropping(photo: DDayEditorModel.EditorPhoto = .none) -> EditorPhotoState {
    var state = EditorPhotoState(photo: photo)
    let requestID = UUID()
    state.apply(.beginLoad(requestID: requestID))
    state.apply(.loadFinished(.success(self.image), requestID: requestID))
    return state
  }

  /// 자르기 중에서 만들기를 시작한 상태와 그 요청 id.
  func rendering() -> (state: EditorPhotoState, requestID: UUID) {
    var state = self.cropping()
    let requestID = UUID()
    state.apply(.beginRender(crop: .zero, requestID: requestID))
    return (state, requestID)
  }

  @Test("불러오기 시작: 처리 중이 아니면 loading 이 되고 안내를 지운다. 처리 중이면 받지 않는다")
  func beginLoad() {
    var state = EditorPhotoState(photo: .none)
    let first = UUID()
    state.apply(.beginLoad(requestID: first))
    state.apply(.loadFinished(.failure(.decodeFailed), requestID: first))
    #expect(state.notice == .loadFailed)

    let startedFromIdle = state.apply(.beginLoad(requestID: UUID()))
    #expect(startedFromIdle)
    #expect(state.step == .loading)
    #expect(state.notice == nil)
    let startedWhileBusy = state.apply(.beginLoad(requestID: UUID()))
    #expect(!startedWhileBusy)
  }

  @Test("불러오기 결과: 지금 요청이면 자르기, 다른 id 는 받지 않는다")
  func loadFinishedMatchesRequest() {
    var state = EditorPhotoState(photo: .none)
    let requestID = UUID()
    state.apply(.beginLoad(requestID: requestID))
    let staleAccepted = state.apply(.loadFinished(.success(self.image), requestID: UUID()))
    #expect(!staleAccepted)
    #expect(state.step == .loading)
    state.apply(.loadFinished(.success(self.image), requestID: requestID))
    #expect(state.step == .cropping(self.image))
    #expect(state.requestID == nil)
  }

  @Test("불러오기 실패: 기존 사진 그대로, tooLarge 만 따로 안내", arguments: [
    (PhotoError.tooLarge, DDayEditorModel.PhotoNotice.tooLarge),
    (PhotoError.readFailed, .loadFailed),
    (PhotoError.decodeFailed, .loadFailed),
  ])
  func loadFailure(error: PhotoError, notice: DDayEditorModel.PhotoNotice) {
    var state = EditorPhotoState(photo: .stored(EditorSample.storedPhoto))
    let requestID = UUID()
    state.apply(.beginLoad(requestID: requestID))
    state.apply(.loadFinished(.failure(error), requestID: requestID))
    #expect(state.step == .idle)
    #expect(state.notice == notice)
    #expect(state.photo == .stored(EditorSample.storedPhoto))
  }

  @Test("불러오기 취소: 기존 사진으로 돌아가고 늦게 온 결과는 받지 않는다. 불러오는 중이 아니면 받지 않는다")
  func cancelLoad() {
    var state = EditorPhotoState(photo: .none)
    let cancelledWhileIdle = state.apply(.cancelLoad)
    #expect(!cancelledWhileIdle)
    let requestID = UUID()
    state.apply(.beginLoad(requestID: requestID))
    let cancelledWhileLoading = state.apply(.cancelLoad)
    #expect(cancelledWhileLoading)
    state.apply(.loadFinished(.success(self.image), requestID: requestID))
    #expect(state.step == .idle)
  }

  @Test("만들기 시작: 자르기 중이면 영역을 맞춰 rendering 이 되고 만들 값이 생긴다. 아니면 받지 않는다")
  func beginRender() throws {
    var idle = EditorPhotoState(photo: .none)
    let acceptedWhileIdle = idle.apply(.beginRender(crop: .zero, requestID: UUID()))
    #expect(!acceptedWhileIdle)
    #expect(idle.renderRequest == nil)

    var state = self.cropping()
    let geometry = try #require(self.image.geometry)
    state.apply(.beginRender(crop: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), requestID: UUID()))
    #expect(state.step == .rendering(self.image))
    let request = try #require(state.renderRequest)
    #expect(request.crop == geometry.defaultCrop)
    #expect(request.image == self.image)
  }

  @Test("만들기 결과: 다른 id 는 받지 않고, 실패면 자르기에 남아 안내, 다시 만들어 성공하면 새 사진")
  func renderFinished() {
    var (state, requestID) = self.rendering()
    state.apply(.renderFinished(.success(EditorSample.cardPhoto()), requestID: UUID()))
    #expect(state.step == .rendering(self.image))

    state.apply(.renderFinished(.failure(.renderFailed), requestID: requestID))
    #expect(state.step == .cropping(self.image))
    #expect(state.notice == .renderFailed)
    #expect(state.photo == .none)
    #expect(state.renderRequest == nil)

    let retryID = UUID()
    state.apply(.beginRender(crop: .zero, requestID: retryID))
    #expect(state.notice == nil)
    state.apply(.renderFinished(.success(EditorSample.cardPhoto()), requestID: retryID))
    #expect(state.step == .idle)
    #expect(state.photo == .new(EditorSample.cardPhoto()))
  }

  @Test("자르기 취소: 자르기 중에만 받고 기존 사진 그대로, 만드는 중에는 받지 않는다")
  func cancelCrop() {
    var (rendering, _) = self.rendering()
    rendering.apply(.cancelCrop)
    #expect(rendering.step == .rendering(self.image))

    var cropping = self.cropping(photo: .stored(EditorSample.storedPhoto))
    cropping.apply(.cancelCrop)
    #expect(cropping.step == .idle)
    #expect(cropping.photo == .stored(EditorSample.storedPhoto))
  }

  @Test("지우기: 처리 중이면 받지 않고, 아니면 사진 없음")
  func remove() {
    var busy = EditorPhotoState(photo: .stored(EditorSample.storedPhoto))
    busy.apply(.beginLoad(requestID: UUID()))
    busy.apply(.remove)
    #expect(busy.photo == .stored(EditorSample.storedPhoto))

    var idle = EditorPhotoState(photo: .stored(EditorSample.storedPhoto))
    idle.apply(.remove)
    #expect(idle.photo == .none)
  }

  @Test("저장된 사진을 잃음: stored 만 없음으로 바꾸고 새로 고른 사진은 그대로")
  func dropStoredPhoto() {
    var stored = EditorPhotoState(photo: .stored(EditorSample.storedPhoto))
    let droppedStored = stored.apply(.dropStoredPhoto)
    #expect(droppedStored)
    #expect(stored.photo == .none)

    var new = EditorPhotoState(photo: .new(EditorSample.cardPhoto()))
    let droppedNew = new.apply(.dropStoredPhoto)
    #expect(!droppedNew)
    #expect(new.photo == .new(EditorSample.cardPhoto()))
  }

  @Test("닫힘: 요청을 끝내 늦게 온 결과를 받지 않고 단계는 그대로 둔다")
  func endRequest() {
    var state = EditorPhotoState(photo: .none)
    let requestID = UUID()
    state.apply(.beginLoad(requestID: requestID))
    state.apply(.endRequest)
    state.apply(.loadFinished(.success(self.image), requestID: requestID))
    #expect(state.step == .loading)
  }
}
