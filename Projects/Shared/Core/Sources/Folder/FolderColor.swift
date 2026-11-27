/// 폴더 색 팔레트 키 (PRODUCT §2 팔레트). 실제 색 값은 DesignSystem 이 정한다.
/// rawValue(= case 이름)는 에셋 이름·로그·테스트에서 쓰는 안정 키라 `DefaultFolderTests` 가 목록을 고정한다
/// (case 이름을 바꾸면 테스트가 깨진다). 저장 문자열은 이 값을 쓰지 않고 DDayStore Impl 매핑의 리터럴로 쓴다 (값은 같다).
public enum FolderColor: String, CaseIterable, Hashable, Sendable {
  case blushPink
  case lavender
  case peach
  case mint
  case butter
}
