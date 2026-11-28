import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import SwiftData
import Testing
@testable import DDayStoreImpl

/// 폴더 쓰기 (`addFolder`·`updateFolder`·`moveFolders`·`deleteFolder`). Impl·Fake 둘 다 "기본 폴더 4개" 상태에서 시작한다.
struct DDayStoreFolderEditingTests {
  /// 기본 폴더 4개가 있는 저장소. Impl 은 `fetchFolders()` 한 번으로 기본 폴더를 만든다 (주입한 makeID 는 쓰지 않는다).
  static func storeWithDefaultFolders(
    _ kind: StoreKind,
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) async throws -> any DDayStoreClient {
    switch kind {
    case .impl:
      let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
      let store = DDayStoreClientImpl(openContainer: { container }, now: TestClock().next, makeID: makeID)
      _ = try await store.fetchFolders()
      return store
    case .fake:
      return DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders, now: TestClock().next, makeID: makeID)
    }
  }

  static func draft(
    _ name: FolderName,
    color: FolderColor = .butter,
    icon: FolderIcon = .gift
  ) -> DDayFolderDraft {
    DDayFolderDraft(name: name, color: color, icon: icon)
  }

  static func dDayDraft(_ title: String, folderID: UUID?, photo: DDayPhotoChange = .keep) -> DDayDraft {
    DDayDraft(title: title, schedule: Sample.draft().schedule, photo: photo, folderID: folderID)
  }

  @Test("addFolder 는 맨 뒤에 정리한 이름으로 추가한다", arguments: StoreKind.allCases)
  func addAppends(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let before = try await store.fetchFolders()

    let added = try await store.addFolder(Self.draft(.custom("  여행 \n"), color: .mint, icon: .airplane))

    #expect(added.name == .custom("여행"))
    #expect(added.color == .mint)
    #expect(added.icon == .airplane)
    #expect(try await store.fetchFolders() == before + [added])
  }

  @Test(
    "addFolder 는 규칙에 맞지 않는 이름과 .system 을 거부하고 id 를 쓰지 않는다",
    arguments: StoreKind.allCases
  )
  func addRejectsInvalidName(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind, makeID: IDSequence([Sample.id(50)]).next)
    let before = try await store.fetchFolders()
    let names: [FolderName] = [
      .custom(""), .custom("   "), .custom(String(repeating: "가", count: 21)), .system(.birthday),
    ]

    for name in names {
      await #expect(throws: DDayStoreError.invalidFolderName) {
        _ = try await store.addFolder(Self.draft(name))
      }
    }

    #expect(try await store.fetchFolders() == before)
    #expect(try await store.addFolder(Self.draft(.custom("새 폴더"))).id == Sample.id(50))
  }

  @Test("addFolder 의 id 가 이미 있으면 alreadyExists 이고 덮지 않는다", arguments: StoreKind.allCases)
  func addRejectsDuplicateID(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind, makeID: IDSequence([Sample.id(10), Sample.id(10)]).next)
    let first = try await store.addFolder(Self.draft(.custom("처음")))

    await #expect(throws: DDayStoreError.alreadyExists) {
      _ = try await store.addFolder(Self.draft(.custom("두 번째"), color: .peach))
    }

    #expect(try await store.fetchFolders().last == first)
    #expect(try await store.fetchFolders().count == 5)
  }

  @Test("updateFolder 는 직접 만든 폴더의 이름·색·아이콘을 바꾸고 자리는 그대로다", arguments: StoreKind.allCases)
  func updateCustomFolder(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let added = try await store.addFolder(Self.draft(.custom("여행")))
    let before = try await store.fetchFolders()

    let updated = try await store.updateFolder(
      id: added.id,
      Self.draft(.custom(" 공부 "), color: .lavender, icon: .book)
    )

    #expect(updated == DDayFolder(id: added.id, name: .custom("공부"), color: .lavender, icon: .book))
    #expect(try await store.fetchFolders() == Array(before.dropLast()) + [updated])
  }

  @Test("기본 폴더는 같은 키의 .system 을 받고, custom 으로 바꾼 뒤에도 .system 으로 되돌릴 수 있다", arguments: StoreKind.allCases)
  func updateDefaultFolderName(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let birthday = try #require(try await store.fetchFolders().first { $0.name == .system(.birthday) })

    let recolored = try await store.updateFolder(id: birthday.id, Self.draft(.system(.birthday), color: .butter))
    #expect(recolored.name == .system(.birthday))
    #expect(recolored.color == .butter)

    let renamed = try await store.updateFolder(id: birthday.id, Self.draft(.custom("우리 가족")))
    #expect(renamed.name == .custom("우리 가족"))

    let restored = try await store.updateFolder(id: birthday.id, Self.draft(.system(.birthday)))
    #expect(restored.name == .system(.birthday))
    #expect(try await store.fetchFolders().first == restored)
  }

  @Test("다른 키의 .system 과 직접 만든 폴더의 .system 은 invalidFolderName", arguments: StoreKind.allCases)
  func updateRejectsWrongSystemName(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let birthday = try #require(try await store.fetchFolders().first { $0.name == .system(.birthday) })
    let custom = try await store.addFolder(Self.draft(.custom("여행")))
    let before = try await store.fetchFolders()

    await #expect(throws: DDayStoreError.invalidFolderName) {
      _ = try await store.updateFolder(id: birthday.id, Self.draft(.system(.couple)))
    }
    await #expect(throws: DDayStoreError.invalidFolderName) {
      _ = try await store.updateFolder(id: custom.id, Self.draft(.system(.other)))
    }
    await #expect(throws: DDayStoreError.invalidFolderName) {
      _ = try await store.updateFolder(id: custom.id, Self.draft(.custom(" ")))
    }

    #expect(try await store.fetchFolders() == before)
  }

  @Test("없는 id 의 updateFolder·deleteFolder 는 notFound", arguments: StoreKind.allCases)
  func missingFolderIsNotFound(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)

    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.updateFolder(id: Sample.id(99), Self.draft(.custom("없음")))
    }
    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.deleteFolder(id: Sample.id(99), dDays: .moveToUnfiled)
    }
    #expect(try await store.fetchFolders().count == 4)
  }

  @Test("moveFolders 는 순서를 바꾸고 fetchFolders 와 같은 값을 돌려준다", arguments: StoreKind.allCases)
  func moveReorders(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let added = try await store.addFolder(Self.draft(.custom("여행")))
    let before = try await store.fetchFolders()
    let reordered = [before[4], before[2], before[0], before[3], before[1]]

    let moved = try await store.moveFolders(reordered.map(\.id))

    #expect(moved == reordered)
    #expect(moved.first == added)
    #expect(try await store.fetchFolders() == moved)
  }

  @Test("moveFolders 는 빠짐·없는 id·중복·빈 배열을 notFound 로 거부하고 순서를 바꾸지 않는다", arguments: StoreKind.allCases)
  func moveRejectsStaleIDs(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let before = try await store.fetchFolders()
    let ids = Array(before.map(\.id).reversed())
    let candidates: [[UUID]] = [
      Array(ids.dropLast()),
      ids + [Sample.id(99)],
      Array(ids.dropLast()) + [ids[0]],
      [],
    ]

    for candidate in candidates {
      await #expect(throws: DDayStoreError.notFound) {
        _ = try await store.moveFolders(candidate)
      }
    }

    #expect(try await store.fetchFolders() == before)
  }

  @Test("deleteFolder(.moveToUnfiled) 는 안의 디데이를 미분류로 남긴다", arguments: StoreKind.allCases)
  func deleteMovesToUnfiled(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let folders = try await store.fetchFolders()
    let target = folders[0]
    let other = folders[1]
    let inside = try await store.add(Self.dDayDraft("안", folderID: target.id))
    let outside = try await store.add(Self.dDayDraft("밖", folderID: other.id))

    let deleted = try await store.deleteFolder(id: target.id, dDays: .moveToUnfiled)

    #expect(deleted.isEmpty)
    #expect(try await store.fetchFolders() == Array(folders.dropFirst()))
    let dDays = try await store.fetchAll()
    #expect(dDays.map(\.id) == [inside.id, outside.id])
    #expect(dDays[0].folderID == nil)
    #expect(dDays[0].updatedAt == inside.updatedAt)
    #expect(dDays[1] == outside)
  }

  @Test("deleteFolder(.delete) 는 안의 디데이를 사진과 함께 지우고 fetchAll 순서로 id 를 돌려준다", arguments: StoreKind.allCases)
  func deleteRemovesDDays(kind: StoreKind) async throws {
    let store = try await Self.storeWithDefaultFolders(kind)
    let folders = try await store.fetchFolders()
    let target = folders[2]
    let first = try await store.add(Self.dDayDraft(
      "첫째",
      folderID: target.id,
      photo: .replace(Sample.cardPhoto(seed: 1))
    ))
    let outside = try await store.add(Self.dDayDraft("밖", folderID: nil, photo: .replace(Sample.cardPhoto(seed: 2))))
    let second = try await store.add(Self.dDayDraft("둘째", folderID: target.id))

    let deleted = try await store.deleteFolder(id: target.id, dDays: .delete)

    #expect(deleted == [first.id, second.id])
    #expect(try await store.fetchAll() == [outside])
    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.fetchPhoto(id: first.id)
    }
    #expect(try await store.fetchPhoto(id: outside.id) == Sample.cardPhoto(seed: 2).image)
    #expect(try await store.fetchFolders().contains { $0.id == target.id } == false)
  }

  @Test("Fake: 주입한 saveFailed 는 네 메서드 모두 아무것도 바꾸지 않는다")
  func fakeSaveFailureChangesNothing() async throws {
    let store = DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders, now: TestClock().next)
    let folders = store.folders
    let dDay = try await store.add(Self.dDayDraft("사진", folderID: folders[0].id, photo: .replace(Sample.cardPhoto())))
    let dDays = store.dDays
    let images = store.photoImages
    let calls: [@Sendable () async throws -> Void] = [
      { _ = try await store.addFolder(Self.draft(.custom("새"))) },
      { _ = try await store.updateFolder(id: folders[0].id, Self.draft(.custom("바꿈"))) },
      { _ = try await store.moveFolders(folders.reversed().map(\.id)) },
      { _ = try await store.deleteFolder(id: folders[0].id, dDays: .delete) },
    ]

    for call in calls {
      store.failNextCall(with: .saveFailed)
      await #expect(throws: DDayStoreError.saveFailed) {
        try await call()
      }
      #expect(store.folders == folders)
      #expect(store.dDays == dDays)
      #expect(store.photoImages == images)
    }
    #expect(dDays.first?.id == dDay.id)

    store.failNextCall(with: .loadFailed)
    await #expect(throws: DDayStoreError.loadFailed) {
      _ = try await store.addFolder(Self.draft(.custom("새")))
    }
    #expect(store.folders == folders)
  }

  @Test("Fake: 이름 거부가 먼저면 주입한 saveFailed 는 사라지고 다음 호출은 성공한다")
  func fakeInvalidNameConsumesInjectedError() async throws {
    let store = DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders, now: TestClock().next)

    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.invalidFolderName) {
      _ = try await store.addFolder(Self.draft(.custom("")))
    }

    let added = try await store.addFolder(Self.draft(.custom("여행")))
    #expect(store.folders.last == added)
  }
}

/// Impl 만: 메모리 컨테이너에 행을 직접 넣거나 디스크 저장소를 다시 연다.
struct DDayStoreFolderEditingImplTests {
  private static func memoryStore() async throws -> (DDayStoreClientImpl, ModelContainer) {
    let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
    let store = DDayStoreClientImpl(openContainer: { container }, now: TestClock().next)
    _ = try await store.fetchFolders()
    return (store, container)
  }

  @Test("기본 폴더를 custom 이름으로 바꿔도 행의 systemKey 는 남는다")
  func renameKeepsSystemKey() async throws {
    let (store, container) = try await Self.memoryStore()
    let birthday = try #require(try await store.fetchFolders().first)

    _ = try await store.updateFolder(id: birthday.id, DDayStoreFolderEditingTests.draft(.custom("우리 생일")))

    let id = birthday.id
    let record = try #require(try ModelContext(container).fetch(
      FetchDescriptor<DDayFolderRecord>(predicate: #Predicate { $0.id == id })
    ).first)
    #expect(record.systemKey == "birthday")
    #expect(record.customName == "우리 생일")
  }

  @Test("읽을 수 없는 폴더 행은 순서 바꾸기에서 빠지고 순서 값이 그대로이며, 새 폴더는 그 뒤로 간다")
  func unreadableFolderRowKeepsOrder() async throws {
    let (store, container) = try await Self.memoryStore()
    let context = ModelContext(container)
    let unreadable = Sample.id(77)
    context.insert(DDayFolderRecord(DDayFolderRecordFields(
      id: unreadable,
      systemKey: nil,
      customName: "모름",
      colorKey: "unknownColor",
      iconKey: "star",
      sortOrder: 100,
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1)
    )))
    try context.save()
    let folders = try await store.fetchFolders()

    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.moveFolders(folders.map(\.id) + [unreadable])
    }
    let moved = try await store.moveFolders(folders.reversed().map(\.id))
    #expect(moved == Array(folders.reversed()))
    let added = try await store.addFolder(DDayStoreFolderEditingTests.draft(.custom("새")))

    let records = try ModelContext(container).fetch(FetchDescriptor<DDayFolderRecord>())
    #expect(records.first { $0.id == unreadable }?.sortOrder == 100)
    #expect(records.first { $0.id == added.id }?.sortOrder == 101)
  }

  @Test("읽을 수 없는 디데이 행은 .delete 에서도 지우지 않고 미분류로 옮기며, 압축본은 지운 디데이만큼 줄어든다")
  func deleteKeepsUnreadableDDayRows() async throws {
    let (store, container) = try await Self.memoryStore()
    let target = try #require(try await store.fetchFolders().first)
    let readable = try await store.add(
      DDayStoreFolderEditingTests.dDayDraft("사진", folderID: target.id, photo: .replace(Sample.cardPhoto(seed: 3)))
    )
    let kept = try await store.add(
      DDayStoreFolderEditingTests.dDayDraft("남음", folderID: nil, photo: .replace(Sample.cardPhoto(seed: 4)))
    )
    let context = ModelContext(container)
    var fields = DDayRecordMapping.fields(
      id: Sample.id(66),
      draft: Sample.draft("모름"),
      createdAt: Date(timeIntervalSince1970: 5),
      updatedAt: Date(timeIntervalSince1970: 5)
    )
    fields.dateKind = "unknown"
    fields.folderID = target.id
    context.insert(DDayRecord(fields))
    try context.save()
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayPhotoRecord>()) == 2)

    let deleted = try await store.deleteFolder(id: target.id, dDays: .delete)

    #expect(deleted == [readable.id])
    let check = ModelContext(container)
    let unreadableID = Sample.id(66)
    let rows = try check.fetch(FetchDescriptor<DDayRecord>(predicate: #Predicate { $0.id == unreadableID }))
    #expect(rows.count == 1)
    #expect(rows.first?.folderID == nil)
    let photoRows = try check.fetch(FetchDescriptor<DDayPhotoRecord>())
    #expect(photoRows.map(\.dDayID) == [kept.id])
  }

  @Test("디스크 저장소: 추가·이름 변경·순서 변경이 다시 열어도 같고, 폴더를 다 지우면 다시 만들지 않는다")
  func diskRoundTrip() async throws {
    let disk = try TemporaryDiskStore(name: "DDayStoreFolderEditingTests")
    defer { disk.remove() }

    let folders: [DDayFolder]
    do {
      let store = disk.makeStore(now: TestClock().next)
      let defaults = try await store.fetchFolders()
      let added = try await store.addFolder(DDayStoreFolderEditingTests.draft(.custom("여행")))
      _ = try await store.updateFolder(id: defaults[1].id, DDayStoreFolderEditingTests.draft(.custom("우리 집")))
      folders = try await store.moveFolders([added.id] + defaults.map(\.id))
    }
    #expect(try await disk.makeStore().fetchFolders() == folders)

    do {
      let store = disk.makeStore()
      for folder in folders {
        _ = try await store.deleteFolder(id: folder.id, dDays: .moveToUnfiled)
      }
    }
    #expect(try await disk.makeStore().fetchFolders().isEmpty)
  }
}
