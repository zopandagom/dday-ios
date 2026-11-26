import DDayStoreInterface
import Foundation

/// 편집 화면을 여는 방식.
public enum DDayEditorMode: Equatable, Sendable {
  case add
  case edit(DDay)
}

/// 편집 화면이 끝난 이유. 한 모델에서 한 번만 나온다.
public enum DDayEditorOutcome: Equatable, Sendable {
  /// 추가·수정. 저장소가 돌려준 값.
  case saved(DDay)
  /// 수정 모드에서 원래 디데이가 저장소에 없어 새로 저장함. `replacing` 은 원래 id (이제 저장소에 없다).
  case savedAsNew(DDay, replacing: UUID)
  /// 이 id 는 이제 저장소에 없다: 삭제 성공·삭제 `.notFound`, 그리고 원래 디데이가 없다고 알게 된 뒤 저장 없이 닫음.
  case deleted(UUID)
  /// 취소, 변경 버리기, 끌어내려 닫기 (원래 디데이가 있다고 아는 동안).
  case cancelled
}
