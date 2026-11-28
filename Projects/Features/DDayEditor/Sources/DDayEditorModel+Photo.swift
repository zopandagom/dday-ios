import Core
import CoreGraphics
import DDayStoreInterface
import Foundation
import PhotoInterface

public extension DDayEditorModel {
  // MARK: - 사진 (전이 규칙은 `EditorPhotoState`, 적용은 `applyPhotoEvent`·`startPhotoWork` 로만)

  /// 선택 버튼이 사진을 넘김. 같은 차례에 `.loading` 으로 바꾸고 불러오기 Task 를 돌려준다. 고를 수 없으면 nil.
  @discardableResult
  func photoPicked(_ picked: PickedPhoto) -> Task<Void, Never>? {
    let requestID = UUID()
    return self.startPhotoWork(.beginLoad(requestID: requestID)) { _ in
      do throws(PhotoError) {
        return try await .loadFinished(.success(self.photoClient.loadWorkingImage(from: picked)), requestID: requestID)
      } catch {
        return .loadFinished(.failure(error), requestID: requestID)
      }
    }
  }

  /// 불러오는 중 [취소]. 기존 사진으로 돌아가고 늦게 온 결과는 버린다.
  func photoLoadingCancelled() {
    self.applyPhotoEvent(.cancelLoad)
  }

  /// 자르기 화면 [완료]. 영역을 `PhotoCropGeometry.clamped` 로 맞추고 같은 차례에 `.rendering` 으로 바꾼 뒤
  /// 만들기 Task 를 돌려준다. 자르기 중이 아니면 nil.
  @discardableResult
  func cropConfirmed(_ crop: CGRect) -> Task<Void, Never>? {
    let requestID = UUID()
    return self.startPhotoWork(.beginRender(crop: crop, requestID: requestID)) { state in
      guard let request = state.renderRequest else {
        return .renderFinished(.failure(.renderFailed), requestID: requestID)
      }
      do throws(PhotoError) {
        let cardPhoto = try await self.photoClient.renderCardPhoto(from: request.image, crop: request.crop)
        return .renderFinished(.success(cardPhoto), requestID: requestID)
      } catch {
        return .renderFinished(.failure(error), requestID: requestID)
      }
    }
  }

  /// 자르기 화면 [취소] (뒤로 가기 포함). 만드는 중과 버리기 확인창이 떠 있는 동안은 무시한다
  /// (확인창 때문에 화면을 잠시 내린 것이라 작업 이미지를 버리지 않는다).
  func cropCancelled() {
    guard !self.isDiscardConfirmationPresented else { return }
    self.applyPhotoEvent(.cancelCrop)
  }

  /// [사진 지우기].
  func photoRemoveTapped() {
    self.applyPhotoEvent(.remove)
  }
}

extension DDayEditorModel {
  /// 사진 이벤트의 통로: 이벤트 전이만 받아 편집 중일 때만 적용하고 받았는지 돌려준다 (적용은 `applyPhotoTransition`).
  @discardableResult
  func applyPhotoEvent(_ event: EditorPhotoState.EventTransition) -> Bool {
    self.applyPhotoTransition(event.transition)
  }
}
