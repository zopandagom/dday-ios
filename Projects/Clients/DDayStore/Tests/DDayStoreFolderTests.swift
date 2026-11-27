import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import SwiftData
import Synchronization
import Testing
@testable import DDayStoreImpl

/// 임시 디렉터리의 디스크 저장소. 테스트가 끝나면 `remove()` 로 지운다.
struct TemporaryDiskStore {
  let directory: URL
  let url: URL

  init(name: String) throws {
    self.directory = URL.temporaryDirectory.appending(path: "\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    self.url = self.directory.appending(path: "DDay.store")
  }

  /// 이 경로를 여는 새 Impl (부를 때마다 새 컨테이너 캐시).
  func makeStore(now: @escaping @Sendable () -> Date = Date.init) -> DDayStoreClientImpl {
    let url = self.url
    return DDayStoreClientImpl(openContainer: { try DDayStoreClientImpl.makeContainer(url: url) }, now: now)
  }

  func remove() {
    try? FileManager.default.removeItem(at: self.directory)
  }
}

/// 기본 폴더(처음 열 때 한 번), folderID 저장·정규화.
struct DDayStoreFolderTests {
  /// 기본 폴더 4개의 기대값 (id 는 저장소가 정해 비교하지 않는다).
  private static func expectDefaultFolders(_ folders: [DDayFolder]) {
    #expect(folders.map(\.name) == DefaultFolder.allCases.map { .system($0) })
    #expect(folders.map(\.color) == DefaultFolder.allCases.map(\.color))
    #expect(folders.map(\.icon) == DefaultFolder.allCases.map(\.icon))
  }

  private static func memoryStore() throws -> (DDayStoreClientImpl, ModelContainer) {
    let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
    return (DDayStoreClientImpl(openContainer: { container }, now: TestClock().next), container)
  }

  @Test("처음 fetchFolders 하면 기본 폴더 4개가 생일·가족·연인·기타 순서로 있다")
  func firstFetchCreatesDefaultFolders() async throws {
    let (store, _) = try Self.memoryStore()

    let folders = try await store.fetchFolders()

    #expect(folders.count == 4)
    Self.expectDefaultFolders(folders)
    #expect(Set(folders.map(\.id)).count == 4)
  }

  @Test("어느 메서드가 처음이어도 기본 폴더가 생긴다 (fetchAll 먼저)")
  func anyFirstCallCreatesDefaultFolders() async throws {
    let (store, container) = try Self.memoryStore()

    #expect(try await store.fetchAll().isEmpty)

    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayFolderRecord>()) == 4)
    try await Self.expectDefaultFolders(store.fetchFolders())
  }

  @Test("디스크 저장소를 새 Impl 로 다시 열어도 기본 폴더는 4개이고 id 가 같다 (중복 없음)")
  func reopenDoesNotDuplicate() async throws {
    let disk = try TemporaryDiskStore(name: "DDayStoreFolderTests")
    defer { disk.remove() }

    let first = try await disk.makeStore().fetchFolders()
    let reopened = try await disk.makeStore().fetchFolders()

    #expect(first.count == 4)
    #expect(reopened == first)
  }

  @Test("폴더를 다 지운 디스크 저장소는 다시 열어도 기본 폴더를 다시 만들지 않는다")
  func deletedFoldersAreNotRecreated() async throws {
    let disk = try TemporaryDiskStore(name: "DDayStoreFolderTests")
    defer { disk.remove() }
    #expect(try await disk.makeStore().fetchFolders().count == 4)

    do {
      let container = try DDayStoreClientImpl.makeContainer(url: disk.url)
      let context = ModelContext(container)
      for record in try context.fetch(FetchDescriptor<DDayFolderRecord>()) {
        context.delete(record)
      }
      try context.save()
    }

    #expect(try await disk.makeStore().fetchFolders().isEmpty)
  }

  @Test("동시에 처음 부른 20개 호출 뒤에도 기본 폴더는 4개다")
  func concurrentFirstCallsCreateOnce() async throws {
    let (store, container) = try Self.memoryStore()

    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0 ..< 20 {
        group.addTask {
          if index.isMultiple(of: 2) {
            _ = try await store.fetchAll()
          } else {
            _ = try await store.fetchFolders()
          }
        }
      }
      try await group.waitForAll()
    }

    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayFolderRecord>()) == 4)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayStoreMetaRecord>()) == 1)
  }

  @Test("add·update 의 folderID 가 왕복하고 디스크 저장소를 다시 열어도 같다")
  func folderIDRoundTrip() async throws {
    let disk = try TemporaryDiskStore(name: "DDayStoreFolderTests")
    defer { disk.remove() }
    let clock = TestClock()

    let updated: DDay
    let unfiled: DDay
    do {
      let store = disk.makeStore(now: clock.next)
      let folders = try await store.fetchFolders()
      let family = try #require(folders.first { $0.name == .system(.family) })
      let couple = try #require(folders.first { $0.name == .system(.couple) })

      let added = try await store.add(DDayDraft(title: "가족", schedule: Sample.draft().schedule, folderID: family.id))
      #expect(added.folderID == family.id)
      updated = try await store.update(
        id: added.id,
        DDayDraft(title: "연인", schedule: Sample.draft().schedule, folderID: couple.id)
      )
      #expect(updated.folderID == couple.id)
      unfiled = try await store.add(Sample.draft("미분류"))
      #expect(unfiled.folderID == nil)
      #expect(try await store.fetchAll() == [updated, unfiled])
    }

    #expect(try await disk.makeStore().fetchAll() == [updated, unfiled])
  }

  @Test("수정에서 folderID 를 nil 로 바꾸면 미분류다")
  func updateToUnfiled() async throws {
    let (store, _) = try Self.memoryStore()
    let folder = try #require(try await store.fetchFolders().first)
    let added = try await store.add(DDayDraft(title: "폴더", schedule: Sample.draft().schedule, folderID: folder.id))

    let updated = try await store.update(id: added.id, DDayDraft(title: "폴더", schedule: Sample.draft().schedule))

    #expect(updated.folderID == nil)
    #expect(try await store.fetchAll().first?.folderID == nil)
  }

  @Test("없는 폴더 id 를 가리키는 draft 는 미분류로 저장·반환한다 (Impl·Fake 같음)", arguments: StoreKind.allCases)
  func missingFolderDraftIsUnfiled(kind: StoreKind) async throws {
    let store: any DDayStoreClient = switch kind {
    case .impl: try Self.memoryStore().0
    case .fake: DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders, now: TestClock().next)
    }
    let missing = Sample.id(99)
    let existing = try #require(try await store.fetchFolders().first)

    let added = try await store.add(DDayDraft(title: "없는 폴더", schedule: Sample.draft().schedule, folderID: missing))
    #expect(added.folderID == nil)
    #expect(try await store.fetchAll().first?.folderID == nil)

    let moved = try await store.update(
      id: added.id,
      DDayDraft(title: "있는 폴더", schedule: Sample.draft().schedule, folderID: existing.id)
    )
    #expect(moved.folderID == existing.id)

    let missingAgain = try await store.update(
      id: added.id,
      DDayDraft(title: "다시 없는 폴더", schedule: Sample.draft().schedule, folderID: missing)
    )
    #expect(missingAgain.folderID == nil)
    #expect(try await store.fetchAll() == [missingAgain])
  }

  @Test("행에 없는 폴더 id 를 쓴 디데이는 fetchAll 에서 미분류이고 행은 읽는다")
  func danglingFolderIDRowIsUnfiled() async throws {
    let (store, container) = try Self.memoryStore()
    _ = try await store.fetchFolders()

    let context = ModelContext(container)
    var fields = DDayRecordMapping.fields(
      id: Sample.id(5),
      draft: Sample.draft("떠돌이"),
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10)
    )
    fields.folderID = Sample.id(99)
    context.insert(DDayRecord(fields))
    try context.save()

    let fetched = try await store.fetchAll()
    #expect(fetched.map(\.id) == [Sample.id(5)])
    #expect(fetched.first?.folderID == nil)
  }

  @Test("모르는 colorKey 의 폴더 행은 fetchFolders 에서 빠지고, 그 폴더를 가리키는 디데이는 미분류다")
  func unreadableFolderRow() async throws {
    let (store, container) = try Self.memoryStore()
    let defaults = try await store.fetchFolders()

    let context = ModelContext(container)
    var folderFields = DDayFolderMapping.fields(
      for: .other,
      id: Sample.id(50),
      createdAt: Date(timeIntervalSince1970: 5)
    )
    folderFields.customName = "깨진 폴더"
    folderFields.colorKey = "red"
    context.insert(DDayFolderRecord(folderFields))
    var dDayFields = DDayRecordMapping.fields(
      id: Sample.id(5),
      draft: Sample.draft(),
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10)
    )
    dDayFields.folderID = Sample.id(50)
    context.insert(DDayRecord(dDayFields))
    try context.save()

    #expect(try await store.fetchFolders() == defaults)
    #expect(try await store.fetchAll().first?.folderID == nil)
    // 읽지 못한 행은 지우지 않는다.
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayFolderRecord>()) == 5)
  }

  @Test("폴더는 순서 → 생성 시각 → id 문자열 순이다")
  func folderOrder() async throws {
    let (store, container) = try Self.memoryStore()
    let defaults = try await store.fetchFolders()

    let context = ModelContext(container)
    let sameTime = Date(timeIntervalSince1970: 5)
    for (id, order) in [(Sample.id(62), 1), (Sample.id(61), 1), (Sample.id(60), 10)] {
      var fields = DDayFolderMapping.fields(for: .other, id: id, createdAt: sameTime)
      fields.customName = "폴더 \(id.uuidString.suffix(2))"
      fields.sortOrder = order
      context.insert(DDayFolderRecord(fields))
    }
    try context.save()

    let ids = try await store.fetchFolders().map(\.id)
    // 기본 폴더 가족(순서 1)은 생성 시각이 지금이라 시각 5 인 두 폴더 뒤다.
    #expect(ids == [
      defaults[0].id, Sample.id(61), Sample.id(62), defaults[1].id, defaults[2].id, defaults[3].id, Sample.id(60),
    ])
  }
}

struct DDayStoreFolderFakeTests {
  @Test("failNextCall 은 fetchFolders 에도 적용되고 상태를 바꾸지 않는다")
  func failNextCallAppliesToFetchFolders() async throws {
    let store = DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders)
    store.failNextCall(with: .loadFailed)

    await #expect(throws: DDayStoreError.loadFailed) {
      _ = try await store.fetchFolders()
    }
    #expect(try await store.fetchFolders() == DDayStoreClientFake.defaultFolders)
    #expect(store.folders == DDayStoreClientFake.defaultFolders)
  }

  @Test("defaultFolders 는 DefaultFolder 순서·값이고 id 가 고정이다")
  func defaultFolders() {
    let folders = DDayStoreClientFake.defaultFolders
    #expect(folders.map(\.name) == DefaultFolder.allCases.map { .system($0) })
    #expect(folders.map(\.color) == DefaultFolder.allCases.map(\.color))
    #expect(folders.map(\.icon) == DefaultFolder.allCases.map(\.icon))
    #expect(folders.map(\.id.uuidString) == [
      "00000000-0000-0000-0000-F00000000001",
      "00000000-0000-0000-0000-F00000000002",
      "00000000-0000-0000-0000-F00000000003",
      "00000000-0000-0000-0000-F00000000004",
    ])
  }

  @Test("Fake 는 기본 폴더를 만들지 않는다")
  func fakeHasNoFoldersByDefault() async throws {
    #expect(try await DDayStoreClientFake().fetchFolders().isEmpty)
  }

  @Test("init 으로 넣은 디데이가 없는 폴더를 가리키면 fetchAll 에서 미분류이고 저장 상태는 그대로다")
  func initialDanglingFolderID() async throws {
    let dangling = DDay(
      id: Sample.id(1),
      title: "떠돌이",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10),
      folderID: Sample.id(99)
    )
    let family = DDayStoreClientFake.defaultFolders[1]
    let filed = DDay(
      id: Sample.id(2),
      title: "가족",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 20),
      updatedAt: Date(timeIntervalSince1970: 20),
      folderID: family.id
    )
    let store = DDayStoreClientFake(dDays: [dangling, filed], folders: DDayStoreClientFake.defaultFolders)

    let fetched = try await store.fetchAll()
    #expect(fetched.map(\.folderID) == [nil, family.id])
    #expect(store.dDays.first?.folderID == Sample.id(99))
  }
}

/// 준비(`prepare`)를 흉내 낸다. 부른 횟수를 세고, 정한 횟수만큼 실패한다.
final class ContainerPreparer: Sendable {
  struct PrepareError: Error {}

  private let state: Mutex<(calls: Int, failuresLeft: Int)>

  init(failures: Int) {
    self.state = Mutex((calls: 0, failuresLeft: failures))
  }

  var calls: Int {
    self.state.withLock { $0.calls }
  }

  func prepare(_: ModelContainer) throws {
    let shouldFail = self.state.withLock { state in
      state.calls += 1
      guard state.failuresLeft > 0 else { return false }
      state.failuresLeft -= 1
      return true
    }
    if shouldFail {
      throw PrepareError()
    }
  }
}

struct DDayContainerCacheTests {
  @Test("준비가 한 번 실패하면 첫 호출은 실패하고 캐시하지 않으며, 다음 호출이 다시 열고 준비해 성공한다")
  func prepareFailureIsNotCached() async throws {
    let opener = ContainerOpener()
    let preparer = ContainerPreparer(failures: 1)
    let cache = DDayContainerCache(open: opener.open, prepare: preparer.prepare)

    await #expect(throws: ContainerPreparer.PrepareError.self) {
      _ = try await cache.container()
    }
    let first = try await cache.container()
    let second = try await cache.container()

    #expect(first === second)
    #expect(opener.attempts == 2)
    #expect(preparer.calls == 2)
  }
}
