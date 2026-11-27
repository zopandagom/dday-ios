import Core
import DDayStoreInterface
import Foundation
import Synchronization

/// 메모리에 디데이를 두는 저장소. 규칙(id 중복·없는 id·시각·순서·사진 변경)은 Impl 과 같다. 읽지 못하는 행은 없다.
/// 주입한 `makeID`·`now` 도 Impl 과 같은 때에 부른다: `add` 는 id 를 먼저 만들고, `add`·`update` 는 읽기 실패·
/// `.notFound`·`.alreadyExists` 판정을 통과한 뒤에 시각을 정한다. 사진 id 는 시각 다음에 makeID 로 만든다
/// (`.replace` 일 때만, Impl 과 같은 때). `failNextCall` 로 넣은 에러도 Impl 이 그 에러로 실패하는 지점에서 던진다:
/// `.saveFailed` 는 시각·사진 id 를 정한 뒤(저장 직전)에, 그 밖의 에러는 처음에 던진다. 실패한 호출은 디데이·압축본을
/// 바꾸지 않는다. `now`·`makeID` 는 잠금 안에서 부를 수 있으므로 이 Fake 를 다시 부르면 안 된다.
public final class DDayStoreClientFake: DDayStoreClient {
  private struct State {
    var dDays: [UUID: DDay]
    /// 디데이 id → 압축본 JPEG.
    var images: [UUID: Data]
    var nextError: DDayStoreError?
  }

  private let state: Mutex<State>
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> UUID

  /// `photoImages` 는 디데이 id → 압축본 JPEG (사진이 있는 디데이의 `fetchPhoto` 결과).
  public init(
    dDays: [DDay] = [],
    photoImages: [UUID: Data] = [:],
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.state = Mutex(State(
      dDays: Dictionary(dDays.map { ($0.id, $0) }) { _, last in last },
      images: photoImages,
      nextError: nil
    ))
    self.now = now
    self.makeID = makeID
  }

  /// 지금 저장된 디데이 (fetchAll 과 같은 순서).
  public var dDays: [DDay] {
    self.state.withLock { Self.sorted($0.dDays) }
  }

  /// 지금 저장된 압축본 (디데이 id → JPEG). 테스트·Example 확인용.
  public var photoImages: [UUID: Data] {
    self.state.withLock { $0.images }
  }

  /// 다음 호출 한 번(어느 메서드든)이 `error` 로 실패한다. 실패한 호출은 상태를 바꾸지 않는다.
  /// 그 호출이 먼저 `.notFound`·`.alreadyExists` 로 끝나면 넣은 에러는 쓰이지 않고 사라진다 (Impl 이 저장까지 가지 않는 것과 같다).
  public func failNextCall(with error: DDayStoreError) {
    self.state.withLock { $0.nextError = error }
  }

  public func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> [DDay] in
      try Self.takeNextError(&locked)
      return Self.sorted(locked.dDays)
    }
  }

  public func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    let id = self.makeID()
    return try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard locked.dDays[id] == nil else { throw DDayStoreError.alreadyExists }
      let timestamp = self.now()
      let newPhoto = self.makeNewPhoto(for: draft.photo)
      if let injected {
        throw injected
      }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: timestamp,
        updatedAt: timestamp,
        photo: newPhoto?.photo
      )
      locked.dDays[id] = dDay
      // 추가에서 `.keep`·`.remove` 는 사진 없음. 새 id 라 남은 압축본은 없지만 맞춰 둔다.
      locked.images[id] = newPhoto?.image
      return dDay
    }
  }

  public func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard let existing = locked.dDays[id] else { throw DDayStoreError.notFound }
      let timestamp = self.now()
      let newPhoto = self.makeNewPhoto(for: draft.photo)
      if let injected {
        throw injected
      }
      let photo: DDayPhoto?
      switch draft.photo {
      case .keep:
        photo = existing.photo
      case .replace:
        photo = newPhoto?.photo
        locked.images[id] = newPhoto?.image
      case .remove:
        photo = nil
        locked.images[id] = nil
      }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: existing.createdAt,
        updatedAt: timestamp,
        photo: photo
      )
      locked.dDays[id] = dDay
      return dDay
    }
  }

  public func delete(id: UUID) async throws(DDayStoreError) {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard locked.dDays[id] != nil else { throw DDayStoreError.notFound }
      if let injected {
        throw injected
      }
      locked.dDays[id] = nil
      locked.images[id] = nil
    }
  }

  public func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> Data? in
      try Self.takeNextError(&locked)
      guard let dDay = locked.dDays[id] else { throw DDayStoreError.notFound }
      guard dDay.photo != nil else { return nil }
      return locked.images[id]
    }
  }

  /// `.replace` 면 새 사진 id 를 만들어 목록용 사진과 압축본을 돌려준다 (시각 다음에 부른다, Impl 과 같은 때).
  private func makeNewPhoto(for change: DDayPhotoChange) -> (photo: DDayPhoto, image: Data)? {
    guard case let .replace(cardPhoto) = change else { return nil }
    return (DDayPhoto(id: self.makeID(), thumbnail: cardPhoto.thumbnail), cardPhoto.image)
  }

  private static func takeNextError(_ state: inout State) throws(DDayStoreError) {
    if let error = state.nextError {
      state.nextError = nil
      throw error
    }
  }

  /// 넣은 에러를 꺼낸다. `.saveFailed` 가 아니면 바로 던지고, `.saveFailed` 면 저장 직전에 던지도록 돌려준다.
  private static func takeErrorBeforeSave(_ state: inout State) throws(DDayStoreError) -> DDayStoreError? {
    guard let error = state.nextError else { return nil }
    state.nextError = nil
    guard error == .saveFailed else { throw error }
    return error
  }

  private static func sorted(_ dDays: [UUID: DDay]) -> [DDay] {
    dDays.values.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }
}
