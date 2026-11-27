import Core
import CoreGraphics
import DDayStoreInterface
import Foundation
import PhotoInterface

/// 편집 화면의 사진 상태와 전이 규칙. `DDayEditorModel` 이 `photoState` 로 하나 갖는다.
///
/// - 필드는 `private(set)` 이고 바꾸는 길은 `apply(_:)` 하나뿐이다. 전이(`Transition`)마다 받을 수 있는 단계가
///   정해져 있고, 받을 수 없는 전이는 아무것도 바꾸지 않는다.
/// - 처리(불러오기·만들기)는 시작 전이에서 요청 id 를 받는다. 결과 전이는 그 id 가 지금 요청일 때만 받고, 받으면
///   요청을 끝낸다. 취소·닫기도 요청을 끝내 늦게 온 결과를 버린다.
/// - 편집 phase(저장·삭제 중, 끝남)는 보지 않는다. `DDayEditorModel` 의 사진 통로가 본다. 통로는 사용자 이벤트
///   (`EventTransition`)·처리 시작(`StartTransition`)·처리 결과(`FinishTransition`)만 받고, `.dropStoredPhoto`·
///   `.endRequest` 는 Model 이 저장 결과·닫기에서만 적용한다.
public struct EditorPhotoState: Equatable, Sendable {
  public typealias EditorPhoto = DDayEditorModel.EditorPhoto
  public typealias PhotoStep = DDayEditorModel.PhotoStep
  public typealias PhotoNotice = DDayEditorModel.PhotoNotice

  /// 사진 상태를 바꾸는 일.
  enum Transition: Sendable {
    /// 고른 사진 불러오기 시작. 처리 중이 아닐 때만.
    case beginLoad(requestID: UUID)
    /// 불러오는 중 [취소]. 기존 사진으로 돌아간다.
    case cancelLoad
    /// 불러오기 결과. 지금 요청일 때만.
    case loadFinished(Result<PhotoWorkingImage, PhotoError>, requestID: UUID)
    /// 자르기 [완료]. 자르기 중일 때만. 영역을 맞출 수 없으면 안내만 띄우고 받지 않는다.
    case beginRender(crop: CGRect, requestID: UUID)
    /// 만들기 결과. 지금 요청일 때만.
    case renderFinished(Result<CardPhoto, PhotoError>, requestID: UUID)
    /// 자르기 [취소]. 자르기 중일 때만 (만드는 중에는 받지 않는다).
    case cancelCrop
    /// [사진 지우기]. 처리 중이 아닐 때만.
    case remove
    /// 원래 디데이와 함께 저장된 사진이 지워졌다 (수정 저장의 `.notFound`). 저장된 사진일 때만.
    case dropStoredPhoto
    /// 화면이 닫힘: 진행 중인 요청을 끝낸다. 단계는 그대로 둔다 (닫힌 화면이라 보이지 않는다).
    case endRequest
  }

  /// 사진 이벤트가 Model 통로(`applyPhotoEvent`)로 넘기는 전이.
  enum EventTransition: Sendable {
    case cancelLoad
    case cancelCrop
    case remove

    var transition: Transition {
      switch self {
      case .cancelLoad: .cancelLoad
      case .cancelCrop: .cancelCrop
      case .remove: .remove
      }
    }
  }

  /// 처리를 시작하는 전이 (Model 통로 `startPhotoWork`).
  enum StartTransition: Sendable {
    case beginLoad(requestID: UUID)
    case beginRender(crop: CGRect, requestID: UUID)

    var transition: Transition {
      switch self {
      case let .beginLoad(requestID): .beginLoad(requestID: requestID)
      case let .beginRender(crop, requestID): .beginRender(crop: crop, requestID: requestID)
      }
    }
  }

  /// 처리 결과 전이 (`startPhotoWork` 의 작업이 돌려준다).
  enum FinishTransition: Sendable {
    case loadFinished(Result<PhotoWorkingImage, PhotoError>, requestID: UUID)
    case renderFinished(Result<CardPhoto, PhotoError>, requestID: UUID)

    var transition: Transition {
      switch self {
      case let .loadFinished(result, requestID): .loadFinished(result, requestID: requestID)
      case let .renderFinished(result, requestID): .renderFinished(result, requestID: requestID)
      }
    }
  }

  /// 만들기에 넘길 값.
  struct RenderRequest: Sendable {
    let image: PhotoWorkingImage
    let crop: CGRect
  }

  public private(set) var photo: EditorPhoto
  public private(set) var step: PhotoStep = .idle
  public private(set) var notice: PhotoNotice?
  /// 진행 중인 처리 요청. 결과 전이는 이 id 와 같을 때만 받는다.
  private(set) var requestID: UUID?
  /// 만드는 중(`.rendering`)일 때 맞춘 영역.
  private var renderCrop: CGRect?

  init(photo: EditorPhoto) {
    self.photo = photo
  }

  /// 처리 중이 아니다 (사진을 고르거나 지울 수 있다).
  var isIdle: Bool { self.step == .idle }

  /// 만드는 중이면 만들 이미지와 맞춘 영역.
  var renderRequest: RenderRequest? {
    guard case let .rendering(image) = self.step, let crop = self.renderCrop else { return nil }
    return RenderRequest(image: image, crop: crop)
  }

  /// 전이를 적용한다. 받았으면 true, 받을 수 없는 전이면 아무것도 바꾸지 않고 false
  /// (예외: 영역을 맞출 수 없는 `beginRender` 는 안내만 띄우고 false).
  @discardableResult
  mutating func apply(_ transition: Transition) -> Bool {
    switch transition {
    case let .beginLoad(requestID): self.beginLoad(requestID: requestID)
    case .cancelLoad: self.cancelLoad()
    case let .loadFinished(result, requestID): self.loadFinished(result, requestID: requestID)
    case let .beginRender(crop, requestID): self.beginRender(crop: crop, requestID: requestID)
    case let .renderFinished(result, requestID): self.renderFinished(result, requestID: requestID)
    case .cancelCrop: self.cancelCrop()
    case .remove: self.remove()
    case .dropStoredPhoto: self.dropStoredPhoto()
    case .endRequest: self.endRequest()
    }
  }

  // MARK: - 전이 (apply 에서만 부른다)

  private mutating func beginLoad(requestID: UUID) -> Bool {
    guard self.isIdle else { return false }
    self.notice = nil
    self.step = .loading
    self.requestID = requestID
    return true
  }

  private mutating func cancelLoad() -> Bool {
    guard self.step == .loading else { return false }
    self.step = .idle
    self.requestID = nil
    return true
  }

  /// 성공이면 자르기, 실패면 기존 사진 그대로 안내 (`.tooLarge` 만 따로, 그 밖은 `.loadFailed`).
  private mutating func loadFinished(_ result: Result<PhotoWorkingImage, PhotoError>, requestID: UUID) -> Bool {
    guard self.requestID == requestID, self.step == .loading else { return false }
    self.requestID = nil
    switch result {
    case let .success(image):
      self.step = .cropping(image)
    case let .failure(error):
      self.step = .idle
      self.notice = error == .tooLarge ? .tooLarge : .loadFailed
    }
    return true
  }

  /// 영역을 `PhotoCropGeometry.clamped` 로 맞추고 `.rendering` 으로 바꾼다.
  private mutating func beginRender(crop: CGRect, requestID: UUID) -> Bool {
    guard case let .cropping(image) = self.step else { return false }
    guard let rect = image.geometry?.clamped(crop) else {
      self.notice = .renderFailed
      return false
    }
    self.notice = nil
    self.step = .rendering(image)
    self.renderCrop = rect
    self.requestID = requestID
    return true
  }

  /// 성공이면 새 사진, 실패면 자르기 화면에 남아 안내 (다시 [완료]·[취소] 할 수 있다).
  private mutating func renderFinished(_ result: Result<CardPhoto, PhotoError>, requestID: UUID) -> Bool {
    guard self.requestID == requestID, case let .rendering(image) = self.step else { return false }
    self.requestID = nil
    self.renderCrop = nil
    switch result {
    case let .success(cardPhoto):
      self.photo = .new(cardPhoto)
      self.step = .idle
    case .failure:
      self.step = .cropping(image)
      self.notice = .renderFailed
    }
    return true
  }

  private mutating func cancelCrop() -> Bool {
    guard case .cropping = self.step else { return false }
    self.step = .idle
    self.notice = nil
    return true
  }

  private mutating func remove() -> Bool {
    guard self.isIdle else { return false }
    self.photo = .none
    self.notice = nil
    return true
  }

  /// 새로 고른 사진은 그대로 둔다.
  private mutating func dropStoredPhoto() -> Bool {
    guard case .stored = self.photo else { return false }
    self.photo = .none
    return true
  }

  private mutating func endRequest() -> Bool {
    self.requestID = nil
    return true
  }
}
