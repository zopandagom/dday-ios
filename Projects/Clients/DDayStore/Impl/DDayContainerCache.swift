import SwiftData

/// 컨테이너를 한 번만 열어 캐시한다. 열기에 실패하면 기억하지 않아 다음 호출이 다시 연다.
///
/// actor 라 동시에 처음 부른 호출들은 차례로 들어오고, `container()` 안에 await 가 없어 재진입도 없다:
/// 첫 호출이 열고(성공이면 캐시) 나면 뒤 호출은 캐시를 받는다. 열기는 이 actor 에서 동기로 실행되어 메인을 막지 않는다.
actor DDayContainerCache {
  private let open: @Sendable () throws -> ModelContainer
  private var cached: ModelContainer?

  init(open: @escaping @Sendable () throws -> ModelContainer) {
    self.open = open
  }

  /// 열린 컨테이너. 아직 없으면 지금 연다. 실패하면 `open` 의 에러를 그대로 던진다 (로그·도메인 에러 변환은 Impl).
  func container() throws -> ModelContainer {
    if let cached = self.cached {
      return cached
    }
    let container = try self.open()
    self.cached = container
    return container
  }
}
