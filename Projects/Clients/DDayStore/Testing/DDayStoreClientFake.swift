import Core
import DDayStoreInterface
import Foundation
import Synchronization

/// 메모리에 디데이를 두는 저장소. 규칙(id 중복·없는 id·시각·순서)은 Impl 과 같다. 읽지 못하는 행은 없다.
public final class DDayStoreClientFake: DDayStoreClient {
  private struct State {
    var dDays: [UUID: DDay]
    var nextError: DDayStoreError?
  }

  private let state: Mutex<State>
  private let now: @Sendable () -> Date
  private let makeID: @Sendable () -> UUID

  public init(
    dDays: [DDay] = [],
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.state = Mutex(State(dDays: Dictionary(dDays.map { ($0.id, $0) }) { _, last in last }, nextError: nil))
    self.now = now
    self.makeID = makeID
  }

  /// 지금 저장된 디데이 (fetchAll 과 같은 순서).
  public var dDays: [DDay] {
    self.state.withLock { Self.sorted($0.dDays) }
  }

  /// 다음 호출 한 번(어느 메서드든)이 `error` 로 실패한다. 실패한 호출은 상태를 바꾸지 않는다.
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
    let timestamp = self.now()
    return try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      try Self.takeNextError(&locked)
      guard locked.dDays[id] == nil else { throw DDayStoreError.alreadyExists }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: timestamp,
        updatedAt: timestamp
      )
      locked.dDays[id] = dDay
      return dDay
    }
  }

  public func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    let timestamp = self.now()
    return try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      try Self.takeNextError(&locked)
      guard let existing = locked.dDays[id] else { throw DDayStoreError.notFound }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: existing.createdAt,
        updatedAt: timestamp
      )
      locked.dDays[id] = dDay
      return dDay
    }
  }

  public func delete(id: UUID) async throws(DDayStoreError) {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) in
      try Self.takeNextError(&locked)
      guard locked.dDays.removeValue(forKey: id) != nil else { throw DDayStoreError.notFound }
    }
  }

  private static func takeNextError(_ state: inout State) throws(DDayStoreError) {
    if let error = state.nextError {
      state.nextError = nil
      throw error
    }
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
