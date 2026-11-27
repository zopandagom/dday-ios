import SwiftData

/// 컨테이너를 한 번만 열고 준비해 캐시한다. 열기나 준비에 실패하면 기억하지 않아 다음 호출이 다시 열고 준비한다.
///
/// 준비(`prepare`)는 연 컨테이너에 한 번 하는 일이다 (기본 폴더 만들기, `DDayDefaultFolders`). 준비에 실패한 컨테이너는
/// 캐시하지 않으므로 열기 실패와 같은 규칙이다.
///
/// actor 라 동시에 처음 부른 호출들은 차례로 들어오고, `container()` 안에 await 가 없어 재진입도 없다:
/// 첫 호출이 열고 준비하고(성공이면 캐시) 나면 뒤 호출은 캐시를 받는다. 열기·준비는 이 actor 에서 동기로 실행되어
/// 메인을 막지 않는다.
actor DDayContainerCache {
  private let open: @Sendable () throws -> ModelContainer
  private let prepare: @Sendable (ModelContainer) throws -> Void
  private var cached: ModelContainer?

  init(
    open: @escaping @Sendable () throws -> ModelContainer,
    prepare: @escaping @Sendable (ModelContainer) throws -> Void
  ) {
    self.open = open
    self.prepare = prepare
  }

  /// 열고 준비한 컨테이너. 아직 없으면 지금 연다. 실패하면 `open`·`prepare` 의 에러를 그대로 던진다
  /// (로그·도메인 에러 변환은 Impl).
  func container() throws -> ModelContainer {
    if let cached = self.cached {
      return cached
    }
    let container = try self.open()
    try self.prepare(container)
    self.cached = container
    return container
  }
}
