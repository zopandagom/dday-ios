import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// `dDaySavedAsNew(_:replacing:)`: 수정 중 원래 디데이가 저장소에 없어 새로 저장한 결과.
extension HomeModelTests {
  /// 원래 디데이(`HomeSample.mixed` 의 3번, D-3)를 대신하는 새 디데이 (D-1).
  var savedAsNewOriginalID: UUID {
    HomeSample.id(3)
  }

  var savedAsNew: DDay {
    HomeSample.dDay(8, HomeSample.solar(2026, 11, 27))
  }

  /// 원래 항목이 빠지고 새 항목이 들어간 정렬 순서.
  var savedAsNewOrder: [UUID] {
    [6, 8, 7, 4, 5, 2, 1].map { HomeSample.id($0) }
  }

  /// 저장소가 새로 저장을 반영한 뒤의 내용 (원래 없음, 새 있음).
  var mixedAfterSavedAsNew: [DDay] {
    HomeSample.mixed.filter { $0.id != self.savedAsNewOriginalID } + [self.savedAsNew]
  }

  @Test("새로 저장하면 다시 읽지 않고 원래 항목을 빼고 새 항목을 정렬 자리에 넣는다")
  func dDaySavedAsNewReplacesWithoutFetch() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    let task = model.dDaySavedAsNew(self.savedAsNew, replacing: self.savedAsNewOriginalID)

    #expect(task == nil)
    #expect(model.content.ids == self.savedAsNewOrder)
    #expect(model.content.items?.first { $0.id == self.savedAsNew.id }?.dDay == self.savedAsNew)
    let fresh = await self.freshOrder(self.mixedAfterSavedAsNew)
    #expect(model.content.ids == fresh)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("원래 id 가 목록에 없어도 새 항목은 들어간다")
  func dDaySavedAsNewUnknownOriginalInserts() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    model.dDaySavedAsNew(self.savedAsNew, replacing: HomeSample.id(99))

    #expect(model.content.ids == [6, 8, 3, 7, 4, 5, 2, 1].map { HomeSample.id($0) })
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("불러오는 중에 온 새로 저장은 불러온 목록에 적용된다", arguments: [true, false])
  func dDaySavedAsNewDuringLoadingAppliesAfterLoad(fetchIncludesOriginal: Bool) async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    #expect(model.dDaySavedAsNew(self.savedAsNew, replacing: self.savedAsNewOriginalID) == nil)
    #expect(model.content == .loading)
    // 받은 목록에 원래 항목이 남아 있거나(true), 이미 새 항목이 들어 있거나(false).
    let fetched = fetchIncludesOriginal ? HomeSample.mixed : self.mixedAfterSavedAsNew
    try store.resumeFetch(with: .success(fetched))
    await task.value

    #expect(model.content.ids == self.savedAsNewOrder)
    #expect(model.content.items?.first { $0.id == self.savedAsNew.id }?.dDay == self.savedAsNew)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("불러오기 실패 중 새로 저장이 오면 다시 불러와 저장소 값이 보인다")
  func dDaySavedAsNewWhenLoadFailedReloads() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    let task = model.dDaySavedAsNew(self.savedAsNew, replacing: self.savedAsNewOriginalID)

    #expect(task != nil)
    try await store.waitForPendingFetches()
    #expect(model.content == .loading)
    try store.resumeFetch(with: .success(self.mixedAfterSavedAsNew))
    await task?.value
    #expect(model.content.ids == self.savedAsNewOrder)
    #expect(store.fetchAllCallCount == 2)
  }

  @Test("원래 항목을 홈에서 지우는 중에 새로 저장이 오면, 홈 삭제 결과와 상관없이 원래 항목은 돌아오지 않는다", arguments: [true, false])
  func dDaySavedAsNewWhileOriginalDeletingDoesNotRestore(deleteSucceeds: Bool) async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let originalID = self.savedAsNewOriginalID

    let task = model.deleteSwiped(id: originalID)
    model.dDaySavedAsNew(self.savedAsNew, replacing: originalID)
    #expect(model.content.ids == self.savedAsNewOrder)
    try await store.waitForPendingDelete(id: originalID)
    try store.resumeDelete(id: originalID, with: deleteSucceeds ? .success(()) : .failure(.saveFailed))
    await task?.value

    #expect(model.content.ids == self.savedAsNewOrder)
    #expect(model.isDeleteFailedAlertPresented == !deleteSucceeds)
  }
}
