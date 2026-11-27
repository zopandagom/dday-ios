import Core
import DDayStoreInterface
import Foundation
import PhotoInterface

public extension DDayEditorModel {
  enum CalendarKind: Hashable, Sendable, CaseIterable {
    case solar
    case lunar
  }

  enum Phase: Equatable, Sendable {
    case editing
    case saving
    case deleting
    case finished
  }

  enum Alert: Equatable, Sendable {
    case saveFailed
    case notFoundOnSave
    case deleteFailed
  }

  /// 편집 화면의 사진.
  enum EditorPhoto: Equatable, Sendable {
    /// 사진 없음 (처음부터 없거나 지움).
    case none
    /// 저장된 사진 유지.
    case stored(DDayPhoto)
    /// 이번에 만든 사진 (저장 때 `.replace`).
    case new(CardPhoto)
  }

  /// 사진 처리 단계.
  enum PhotoStep: Equatable, Sendable {
    case idle
    /// 고른 사진 읽기·디코딩 중 (사진 섹션에 진행 표시 + [취소]).
    case loading
    /// 자르기 화면.
    case cropping(PhotoWorkingImage)
    /// 자르기 화면에서 [완료] 뒤 만드는 중 (버튼·제스처 비활성).
    case rendering(PhotoWorkingImage)
  }

  /// 사진 처리 안내.
  enum PhotoNotice: Equatable, Sendable {
    /// 불러오기의 `.readFailed`·`.decodeFailed` (그 밖의 case 도) → 사진 섹션 footer.
    case loadFailed
    /// 불러오기의 `.tooLarge` → 사진 섹션 footer.
    case tooLarge
    /// 만들기 실패 → 자르기 화면 안내.
    case renderFailed
  }
}
