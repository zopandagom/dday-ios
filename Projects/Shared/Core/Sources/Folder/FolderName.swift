/// 폴더 이름: 기본 이름(앱 언어로 표시) 또는 사용자가 정한 이름(그대로 표시).
/// DesignSystem(Shared)이 이름 → `Text` 변환을 한 곳에 두도록 Client Interface 가 아니라 Core 에 둔다.
public enum FolderName: Hashable, Sendable {
  /// 기본 폴더의 이름. 앱 언어로 보인다.
  case system(DefaultFolder)
  /// 사용자가 정한 이름. 그대로 보인다.
  case custom(String)
}
