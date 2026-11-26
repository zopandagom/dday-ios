import Core
import DDayStoreInterface
import Foundation
import os
import SwiftData

/// SwiftData 로 디데이를 기기 안에만 저장한다.
///
/// - 메서드마다 자기 `ModelContext` 를 만들고(자동 저장 끔) 명시적 `save()` 한 번으로 저장한다. 저장에 실패하면
///   `rollback()` 해서 이 호출의 변경은 하나도 남지 않는다.
/// - 저장소(컨테이너)는 처음 쓰는 호출에서 `DDayContainerCache` 로 연다. 열지 못하면 그 호출이 `.loadFailed` 를 던지고,
///   실패는 기억하지 않아 다음 호출이 다시 연다. 연 컨테이너는 캐시한다.
/// - 가변 상태는 컨테이너 캐시(actor)뿐이고 열기 안에 await 가 없어 재진입 문제는 없다.
/// - 동시 수정은 나중에 저장한 draft 전체가 이긴다 (두 draft 가 섞이지 않음). 수정과 삭제가 겹쳐 삭제가 먼저 저장되면
///   수정은 성공을 돌려주지만 행은 삭제된 채로 남는다.
/// - 취소는 확인하지 않는다. 시작한 작업은 끝까지 해서 반쯤 저장된 상태가 없다.
/// - 로그에는 작업 이름·에러 타입 이름·건너뛴 행 수만 남긴다 (제목·날짜·id 는 남기지 않는다, PRODUCT §1).
///   이 값들은 사용자 데이터가 아니므로 진단할 수 있게 `privacy: .public` 으로 남긴다.
public final class DDayStoreClientImpl: DDayStoreClient {
  let containerCache: DDayContainerCache
  let now: @Sendable () -> Date
  let makeID: @Sendable () -> UUID
  private static let logger = Logger(subsystem: "com.zopandagom.dday", category: "DDayStore")

  /// 기기 디스크의 기본 저장소(Application Support 의 `DDay.store`)를 쓴다. 여기서는 열지 않는다:
  /// 처음 쓰는 호출에서 열고, 열지 못하면 그 호출이 `.loadFailed` 를 던진 뒤 다음 호출에서 다시 연다.
  public convenience init() {
    self.init(openContainer: { try Self.makeContainer(isStoredInMemoryOnly: false) })
  }

  /// 테스트용: 열기를 주입한다 (실패·재시도·캐시 검사, 같은 컨테이너에 행 직접 넣기).
  init(
    openContainer: @escaping @Sendable () throws -> ModelContainer,
    now: @escaping @Sendable () -> Date = Date.init,
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.containerCache = DDayContainerCache(open: openContainer)
    self.now = now
    self.makeID = makeID
  }

  /// `isStoredInMemoryOnly` 가 true 면 테스트용 메모리 저장소(컨테이너마다 따로).
  /// iCloud 동기화가 켜지지 않도록 두 설정 모두 `cloudKitDatabase: .none` 을 명시한다 (기본값은 `.automatic`).
  static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
    let configuration = if isStoredInMemoryOnly {
      ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    } else {
      ModelConfiguration(
        url: URL.applicationSupportDirectory.appending(path: "DDay.store"),
        cloudKitDatabase: .none
      )
    }
    return try ModelContainer(
      for: Schema(versionedSchema: DDaySchemaV1.self),
      migrationPlan: DDayMigrationPlan.self,
      configurations: configuration
    )
  }

  @concurrent
  public func fetchAll() async throws(DDayStoreError) -> [DDay] {
    let context = try await self.makeContext()
    let records: [DDayRecord]
    do {
      records = try context.fetch(FetchDescriptor<DDayRecord>())
    } catch {
      Self.logFailure("fetchAll", error)
      throw DDayStoreError.loadFailed
    }
    var dDays: [DDay] = []
    var skippedCount = 0
    for record in records {
      if let dDay = DDayRecordMapping.dDay(from: record.fields) {
        dDays.append(dDay)
      } else {
        skippedCount += 1
      }
    }
    if skippedCount > 0 {
      // 읽지 못한 행은 지우지 않는다 (나중 버전이 읽거나 마이그레이션할 수 있게).
      Self.logger.error("DDayStore skipped \(skippedCount) unreadable rows")
    }
    return dDays.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  @concurrent
  public func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    // id 는 열기 전에 만든다: 열기 실패(`.loadFailed`)에서도 id 를 하나 쓴 뒤 실패해 Fake 와 실패 지점이 같다.
    let id = self.makeID()
    let context = try await self.makeContext()
    // `@Attribute(.unique)` 는 같은 id 삽입을 에러 없이 덮어쓰므로(upsert) 먼저 확인한다.
    let existingCount: Int
    do {
      existingCount = try context.fetchCount(Self.descriptor(id: id))
    } catch {
      Self.logFailure("add", error)
      throw DDayStoreError.loadFailed
    }
    guard existingCount == 0 else { throw DDayStoreError.alreadyExists }
    let timestamp = self.now()
    context.insert(DDayRecord(DDayRecordMapping.fields(
      id: id,
      draft: draft,
      createdAt: timestamp,
      updatedAt: timestamp
    )))
    try Self.save(context, operation: "add")
    return DDay(
      id: id,
      title: draft.title,
      schedule: draft.schedule,
      reminder: draft.reminder,
      createdAt: timestamp,
      updatedAt: timestamp
    )
  }

  @concurrent
  public func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    let context = try await self.makeContext()
    guard let record = try Self.fetchRecord(id: id, in: context, operation: "update") else {
      throw DDayStoreError.notFound
    }
    let createdAt = record.createdAt
    let timestamp = self.now()
    // 읽지 못하던 행도 모든 필드를 대입해 고쳐진다.
    record.apply(DDayRecordMapping.fields(id: id, draft: draft, createdAt: createdAt, updatedAt: timestamp))
    try Self.save(context, operation: "update")
    return DDay(
      id: id,
      title: draft.title,
      schedule: draft.schedule,
      reminder: draft.reminder,
      createdAt: createdAt,
      updatedAt: timestamp
    )
  }

  @concurrent
  public func delete(id: UUID) async throws(DDayStoreError) {
    let context = try await self.makeContext()
    // `delete(model:where:)` 는 없는 id 에도 에러가 없어 `.notFound` 를 낼 수 없으므로 찾아서 지운다.
    guard let record = try Self.fetchRecord(id: id, in: context, operation: "delete") else {
      throw DDayStoreError.notFound
    }
    context.delete(record)
    try Self.save(context, operation: "delete")
  }

  // MARK: - 내부

  /// 모든 메서드의 첫 단계. 컨테이너를 (처음이면 열어) 받아 컨텍스트를 만든다. 열기 실패는 로그 후 `.loadFailed`.
  private func makeContext() async throws(DDayStoreError) -> ModelContext {
    let container: ModelContainer
    do {
      container = try await self.containerCache.container()
    } catch {
      Self.logFailure("open", error)
      throw DDayStoreError.loadFailed
    }
    let context = ModelContext(container)
    // 실패한 변경이 나중에 자동 저장되지 않도록 끈다 (기본값 true).
    context.autosaveEnabled = false
    return context
  }

  private static func descriptor(id: UUID) -> FetchDescriptor<DDayRecord> {
    var descriptor = FetchDescriptor<DDayRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return descriptor
  }

  private static func fetchRecord(
    id: UUID,
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> DDayRecord? {
    do {
      return try context.fetch(self.descriptor(id: id)).first
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
  }

  private static func save(_ context: ModelContext, operation: String) throws(DDayStoreError) {
    do {
      try context.save()
    } catch {
      context.rollback()
      self.logFailure(operation, error)
      throw DDayStoreError.saveFailed
    }
  }

  private static func logFailure(_ operation: String, _ error: any Error) {
    self.logger.error(
      "DDayStore \(operation, privacy: .public) failed: \(String(describing: type(of: error)), privacy: .public)"
    )
  }
}
