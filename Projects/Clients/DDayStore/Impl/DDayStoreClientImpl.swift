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
/// - 사진: 썸네일·사진 id 는 `DDayRecord` 에, 압축본은 `DDayPhotoRecord`(dDay id unique) 에 둔다. `fetchAll` 은
///   `DDayRecord` 만 읽고 압축본은 `fetchPhoto(id:)` 만 읽는다. `.replace` 는 새 사진 id 를 만들어 두 행에 같은 id 를
///   쓰고, `.remove`·삭제는 압축본 행도 지운다. 모두 그 호출의 한 `save()` 라 실패하면 옛 사진이 그대로 남는다.
///   압축본 행은 먼저 조회해 있으면 고치고 없으면 넣는다 (unique 의 조용한 upsert 에 기대지 않는다).
/// - makeID 순서: `add` 는 디데이 id 를 열기 전에, 사진 id 는 시각 다음에 만든다 (`.replace` 일 때만).
///   `update` 는 `.notFound` 판정·시각 다음에 사진 id 를 만든다. `.notFound`·`.alreadyExists`·열기 실패로 끝난
///   호출은 사진 id·시각을 쓰지 않는다 (`add` 의 디데이 id 는 쓴다). Fake 도 같은 때에 부른다.
/// - 고아 압축본: 수정과 삭제가 겹쳐 삭제가 먼저 저장되면 `.replace` 수정이 넣은 `DDayPhotoRecord` 는 짝 없는
///   고아로 남을 수 있다. 고아는 읽히지 않는다: `fetchAll` 은 압축본 모델을 읽지 않고, `fetchPhoto` 는 먼저
///   `DDayRecord` 를 찾아 없으면 `.notFound` 다. `add` 는 새 id 라 고아의 `dDayID` 와 겹치지 않고, 같은 `dDayID` 로
///   쓰는 경우(수정 `.replace`)는 조회해 덮어쓴다. 고아는 압축본 한 장(수백 KB) 저장 공간만 차지하고 정리는 하지
///   않는다 (홈 스와이프 삭제와 편집 저장이 동시에 일어나야 생기는 드문 경우).
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

  /// `isStoredInMemoryOnly` 가 true 면 테스트용 메모리 저장소(컨테이너마다 따로), 아니면 기기의 기본 저장소.
  static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
    if isStoredInMemoryOnly {
      return try self.makeContainer(
        configuration: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
      )
    }
    return try self.makeContainer(url: URL.applicationSupportDirectory.appending(path: "DDay.store"))
  }

  /// 그 파일 경로의 디스크 저장소 (기본 저장소와 테스트의 임시 디스크 저장소).
  static func makeContainer(url: URL) throws -> ModelContainer {
    try self.makeContainer(configuration: ModelConfiguration(url: url, cloudKitDatabase: .none))
  }

  /// iCloud 동기화가 켜지지 않도록 모든 설정이 `cloudKitDatabase: .none` 을 명시한다 (기본값은 `.automatic`).
  private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(
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
      let photo = DDayRecordMapping.photo(id: record.photoID, thumbnail: record.photoThumbnail)
      if let dDay = DDayRecordMapping.dDay(from: record.fields, photo: photo) {
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
    let record = DDayRecord(DDayRecordMapping.fields(
      id: id,
      draft: draft,
      createdAt: timestamp,
      updatedAt: timestamp
    ))
    context.insert(record)
    // 추가에서 `.keep`·`.remove` 는 사진 없음 (새 행의 사진 필드는 nil).
    if case let .replace(cardPhoto) = draft.photo {
      try Self.writePhoto(cardPhoto, photoID: self.makeID(), to: record, in: context, operation: "add")
    }
    try Self.save(context, operation: "add")
    return DDay(
      id: id,
      title: draft.title,
      schedule: draft.schedule,
      reminder: draft.reminder,
      createdAt: timestamp,
      updatedAt: timestamp,
      photo: DDayRecordMapping.photo(id: record.photoID, thumbnail: record.photoThumbnail)
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
    // 읽지 못하던 행도 모든 필드를 대입해 고쳐진다. 사진 필드는 `apply` 가 건드리지 않아 `.keep` 이면 그대로다.
    record.apply(DDayRecordMapping.fields(id: id, draft: draft, createdAt: createdAt, updatedAt: timestamp))
    switch draft.photo {
    case .keep:
      break
    case let .replace(cardPhoto):
      // 사진 id 는 시각 다음에 만든다 (Fake 와 같은 때).
      try Self.writePhoto(cardPhoto, photoID: self.makeID(), to: record, in: context, operation: "update")
    case .remove:
      record.photoThumbnail = nil
      record.photoID = nil
      if let photoRecord = try Self.fetchPhotoRecord(dDayID: id, in: context, operation: "update") {
        context.delete(photoRecord)
      }
    }
    try Self.save(context, operation: "update")
    return DDay(
      id: id,
      title: draft.title,
      schedule: draft.schedule,
      reminder: draft.reminder,
      createdAt: createdAt,
      updatedAt: timestamp,
      photo: DDayRecordMapping.photo(id: record.photoID, thumbnail: record.photoThumbnail)
    )
  }

  @concurrent
  public func delete(id: UUID) async throws(DDayStoreError) {
    let context = try await self.makeContext()
    // `delete(model:where:)` 는 없는 id 에도 에러가 없어 `.notFound` 를 낼 수 없으므로 찾아서 지운다.
    guard let record = try Self.fetchRecord(id: id, in: context, operation: "delete") else {
      throw DDayStoreError.notFound
    }
    // 압축본 행도 같은 save 에서 지운다 (외부 저장 파일도 이 save 에서 함께 지워진다).
    if let photoRecord = try Self.fetchPhotoRecord(dDayID: id, in: context, operation: "delete") {
      context.delete(photoRecord)
    }
    context.delete(record)
    try Self.save(context, operation: "delete")
  }

  @concurrent
  public func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    let context = try await self.makeContext()
    // 디데이 행을 먼저 찾는다: 짝 없는 고아 압축본은 여기서 `.notFound` 가 되어 읽히지 않는다.
    guard let record = try Self.fetchRecord(id: id, in: context, operation: "fetchPhoto") else {
      throw DDayStoreError.notFound
    }
    guard let photoID = record.photoID else { return nil }
    guard let photoRecord = try Self.fetchPhotoRecord(dDayID: id, in: context, operation: "fetchPhoto") else {
      Self.logger.error("DDayStore fetchPhoto photo row missing")
      return nil
    }
    guard photoRecord.photoID == photoID else {
      Self.logger.error("DDayStore fetchPhoto photo id mismatch")
      return nil
    }
    return photoRecord.imageData
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

  private static func fetchPhotoRecord(
    dDayID: UUID,
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) -> DDayPhotoRecord? {
    var descriptor = FetchDescriptor<DDayPhotoRecord>(predicate: #Predicate { $0.dDayID == dDayID })
    descriptor.fetchLimit = 1
    do {
      return try context.fetch(descriptor).first
    } catch {
      self.logFailure(operation, error)
      throw DDayStoreError.loadFailed
    }
  }

  /// 썸네일·사진 id 를 디데이 행에, 압축본을 압축본 행에 쓴다 (저장은 부른 쪽의 save 한 번).
  /// 압축본 행은 `dDayID` 로 조회해 있으면 고치고 없으면 넣는다 (unique 의 조용한 upsert 에 기대지 않는다).
  private static func writePhoto(
    _ cardPhoto: CardPhoto,
    photoID: UUID,
    to record: DDayRecord,
    in context: ModelContext,
    operation: String
  ) throws(DDayStoreError) {
    record.photoThumbnail = cardPhoto.thumbnail
    record.photoID = photoID
    if let photoRecord = try self.fetchPhotoRecord(dDayID: record.id, in: context, operation: operation) {
      photoRecord.photoID = photoID
      photoRecord.imageData = cardPhoto.image
    } else {
      context.insert(DDayPhotoRecord(dDayID: record.id, photoID: photoID, imageData: cardPhoto.image))
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
