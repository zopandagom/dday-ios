/// 폴더 아이콘 키 (고정 목록). 그림은 DesignSystem 이 정한다 (지금은 SF Symbol, 6단계에 같은 키로 에셋 교체).
/// rawValue(= case 이름)는 저장 문자열이다 (DDayStore V1). 출시 뒤 바꾸지 않는다. `DefaultFolderTests` 가 목록을 고정한다.
public enum FolderIcon: String, CaseIterable, Hashable, Sendable {
  case cake
  case house
  case heart
  case star
  case gift
  case airplane
  case graduationCap
  case book
  case musicNote
  case pawprint
  case briefcase
  case sparkles
}
