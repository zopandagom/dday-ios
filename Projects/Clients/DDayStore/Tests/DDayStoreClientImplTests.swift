import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import SwiftData
import Testing
@testable import DDayStoreImpl

/// 같은 시나리오를 Impl(메모리 컨테이너)과 Fake 에 돌려 규칙이 같은지 본다.
enum StoreKind: String, CaseIterable, Sendable {
  case impl
  case fake

  func make(
    now: @escaping @Sendable () -> Date = TestClock().next,
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) throws -> any DDayStoreClient {
    switch self {
    case .impl:
      let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
      return DDayStoreClientImpl(openContainer: { container }, now: now, makeID: makeID)
    case .fake:
      return DDayStoreClientFake(now: now, makeID: makeID)
    }
  }
}

struct DDayStoreClientRuleTests {
  @Test("빈 저장소는 빈 목록을 돌려준다", arguments: StoreKind.allCases)
  func emptyStore(kind: StoreKind) async throws {
    let store = try kind.make()
    #expect(try await store.fetchAll().isEmpty)
  }

  @Test("추가한 값을 다시 읽으면 같다 (윤달 음력 포함)", arguments: StoreKind.allCases)
  func addThenFetch(kind: StoreKind) async throws {
    let clock = TestClock(start: Date(timeIntervalSince1970: 100))
    let store = try kind.make(now: clock.next, makeID: IDSequence([Sample.id(1), Sample.id(2)]).next)

    let solar = try await store.add(Sample.draft("양력"))
    let lunar = try await store.add(
      Sample.draft(
        "윤달",
        date: Sample.lunar(2025, 6, 15, leap: true),
        repeatRule: .yearly,
        countingStyle: .dPlus,
        reminder: ReminderSettings(isEnabled: false, daysBefore: [1, 3], time: Sample.time(23, 59))
      )
    )

    #expect(solar.id == Sample.id(1))
    #expect(solar.createdAt == Date(timeIntervalSince1970: 101))
    #expect(solar.updatedAt == solar.createdAt)
    #expect(lunar.id == Sample.id(2))
    #expect(lunar.schedule.date == Sample.lunar(2025, 6, 15, leap: true))
    #expect(try await store.fetchAll() == [solar, lunar])
  }

  @Test("수정하면 내용이 바뀌고 생성 시각은 유지, 수정 시각은 갱신된다", arguments: StoreKind.allCases)
  func update(kind: StoreKind) async throws {
    let clock = TestClock(start: Date(timeIntervalSince1970: 100))
    let store = try kind.make(now: clock.next)
    let original = try await store.add(Sample.draft("처음"))

    let newDraft = Sample.draft("바뀜", date: Sample.lunar(2026, 1, 30), countingStyle: .dayOne)
    let updated = try await store.update(id: original.id, newDraft)

    #expect(updated.id == original.id)
    #expect(updated.draft == newDraft)
    #expect(updated.createdAt == original.createdAt)
    #expect(updated.updatedAt == Date(timeIntervalSince1970: 102))
    #expect(try await store.fetchAll() == [updated])
  }

  @Test("삭제하면 목록에서 빠진다", arguments: StoreKind.allCases)
  func delete(kind: StoreKind) async throws {
    let store = try kind.make()
    let first = try await store.add(Sample.draft("하나"))
    let second = try await store.add(Sample.draft("둘"))

    try await store.delete(id: first.id)

    #expect(try await store.fetchAll() == [second])
  }

  @Test("없는 id 를 수정·삭제하면 notFound 이고 저장값은 그대로다", arguments: StoreKind.allCases)
  func notFound(kind: StoreKind) async throws {
    let store = try kind.make()
    let existing = try await store.add(Sample.draft())

    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.update(id: Sample.id(99), Sample.draft("없음"))
    }
    await #expect(throws: DDayStoreError.notFound) {
      try await store.delete(id: Sample.id(99))
    }
    #expect(try await store.fetchAll() == [existing])
  }

  @Test("같은 id 로 다시 추가하면 alreadyExists 이고 첫 값이 덮이지 않는다", arguments: StoreKind.allCases)
  func alreadyExists(kind: StoreKind) async throws {
    let fixedID = Sample.id(7)
    let store = try kind.make(makeID: { fixedID })
    let first = try await store.add(Sample.draft("첫 값"))

    await #expect(throws: DDayStoreError.alreadyExists) {
      _ = try await store.add(Sample.draft(
        "둘째 값",
        reminder: ReminderSettings(daysBefore: [1], time: Sample.time(8, 0))
      ))
    }
    #expect(try await store.fetchAll() == [first])
  }

  @Test("notFound·alreadyExists 로 실패한 호출은 시각을 쓰지 않는다", arguments: StoreKind.allCases)
  func failedCallsDoNotConsumeClock(kind: StoreKind) async throws {
    let clock = TestClock()
    let fixedID = Sample.id(7)
    let ids = IDSequence([fixedID, fixedID, Sample.id(8)])
    let store = try kind.make(now: clock.next, makeID: ids.next)
    let first = try await store.add(Sample.draft("첫 값"))

    await #expect(throws: DDayStoreError.alreadyExists) {
      _ = try await store.add(Sample.draft("같은 id"))
    }
    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.update(id: Sample.id(99), Sample.draft("없음"))
    }
    let second = try await store.add(Sample.draft("둘째 값"))

    #expect(second.createdAt == first.createdAt.addingTimeInterval(1))
  }

  @Test("목록은 생성 시각 오름차순이다", arguments: StoreKind.allCases)
  func orderByCreatedAt(kind: StoreKind) async throws {
    let store = try kind.make(
      now: TestClock().next,
      makeID: IDSequence([Sample.id(3), Sample.id(1), Sample.id(2)]).next
    )
    let third = try await store.add(Sample.draft("먼저"))
    let first = try await store.add(Sample.draft("둘째"))
    let second = try await store.add(Sample.draft("셋째"))

    #expect(try await store.fetchAll() == [third, first, second])
  }

  @Test("생성 시각이 같으면 id 문자열 순이다", arguments: StoreKind.allCases)
  func orderByIDWhenSameTime(kind: StoreKind) async throws {
    let fixedNow = Date(timeIntervalSince1970: 500)
    let store = try kind.make(
      now: { fixedNow },
      makeID: IDSequence([Sample.id(2), Sample.id(3), Sample.id(1)]).next
    )
    _ = try await store.add(Sample.draft("둘"))
    _ = try await store.add(Sample.draft("셋"))
    _ = try await store.add(Sample.draft("하나"))

    #expect(try await store.fetchAll().map(\.id) == [Sample.id(1), Sample.id(2), Sample.id(3)])
  }
}

struct DDayStoreClientImplTests {
  @Test("읽지 못하는 행은 건너뛰고 나머지를 돌려주며, 그 행은 저장소에 남는다")
  func skipsUnreadableRows() async throws {
    let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
    let store = DDayStoreClientImpl(openContainer: { container }, now: TestClock().next)
    let readable = try await store.add(Sample.draft("정상"))

    let context = ModelContext(container)
    var corrupted = DDayRecordMapping.fields(of: readable)
    corrupted.id = Sample.id(42)
    corrupted.dateKind = "unknown"
    context.insert(DDayRecord(corrupted))
    try context.save()

    #expect(try await store.fetchAll() == [readable])
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<DDayRecord>()) == 2)
  }

  @Test("읽지 못하던 행도 수정하면 모든 필드가 바뀌어 다시 읽힌다")
  func updateRepairsUnreadableRow() async throws {
    let container = try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
    let store = DDayStoreClientImpl(openContainer: { container }, now: TestClock().next)

    let context = ModelContext(container)
    var corrupted = DDayRecordMapping.fields(
      id: Sample.id(5),
      draft: Sample.draft(),
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10)
    )
    corrupted.repeatRule = "monthly"
    context.insert(DDayRecord(corrupted))
    try context.save()

    let updated = try await store.update(id: Sample.id(5), Sample.draft("고침"))

    #expect(updated.createdAt == Date(timeIntervalSince1970: 10))
    #expect(try await store.fetchAll() == [updated])
  }
}

struct DDayStoreClientFakeTests {
  @Test("failNextCall 은 다음 호출 한 번만 실패시키고 상태를 바꾸지 않는다")
  func failNextCall() async throws {
    let store = DDayStoreClientFake(now: TestClock().next)
    let existing = try await store.add(Sample.draft())

    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.saveFailed) {
      _ = try await store.add(Sample.draft("실패"))
    }
    #expect(store.dDays == [existing])

    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.saveFailed) {
      try await store.delete(id: existing.id)
    }
    #expect(try await store.fetchAll() == [existing])

    store.failNextCall(with: .loadFailed)
    await #expect(throws: DDayStoreError.loadFailed) {
      _ = try await store.fetchAll()
    }
    #expect(try await store.fetchAll() == [existing])
  }

  @Test("주입한 saveFailed 는 Impl 처럼 시각을 정한 뒤 실패하고, 다른 에러는 시각을 쓰지 않는다")
  func injectedErrorClock() async throws {
    let clock = TestClock()
    let store = DDayStoreClientFake(now: clock.next)
    let first = try await store.add(Sample.draft("첫 값"))

    store.failNextCall(with: .loadFailed)
    await #expect(throws: DDayStoreError.loadFailed) {
      _ = try await store.add(Sample.draft("읽기 실패"))
    }
    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.saveFailed) {
      _ = try await store.update(id: first.id, Sample.draft("저장 실패"))
    }
    let second = try await store.add(Sample.draft("둘째 값"))

    // 첫 값 +1, loadFailed 는 시각을 쓰지 않음, saveFailed 는 +1 을 씀 → 둘째 값은 +2
    #expect(second.createdAt == first.createdAt.addingTimeInterval(2))
    #expect(store.dDays == [first, second])
  }

  @Test("notFound 로 먼저 끝난 호출에 넣은 saveFailed 는 다음 호출로 넘어가지 않는다")
  func injectedSaveFailedConsumedByNotFound() async throws {
    let store = DDayStoreClientFake(now: TestClock().next)
    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.notFound) {
      try await store.delete(id: Sample.id(99))
    }
    _ = try await store.add(Sample.draft())
    #expect(store.dDays.count == 1)
  }

  @Test("처음 넣은 디데이를 목록 순서대로 돌려준다")
  func initialDDays() async throws {
    let later = DDay(
      id: Sample.id(1),
      title: "나중",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 20),
      updatedAt: Date(timeIntervalSince1970: 20)
    )
    let earlier = DDay(
      id: Sample.id(2),
      title: "먼저",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10)
    )
    let store = DDayStoreClientFake(dDays: [later, earlier])

    #expect(try await store.fetchAll() == [earlier, later])
    #expect(store.dDays == [earlier, later])
  }
}
