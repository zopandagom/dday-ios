import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

extension HomeModelTests {
  // MARK: calendarDayChanged

  @Test("날짜가 바뀌면 다시 정렬한다")
  func calendarDayChangedReorders() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.dayShift))
    await model.onAppear()

    self.clock.day = HomeSample.day(2026, 11, 27)
    model.calendarDayChanged()

    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
    #expect(model.content.items?.allSatisfy {
      $0.status == DDayStatus(schedule: $0.dDay.schedule, today: HomeSample.day(2026, 11, 27))
    } == true)
  }

  @Test("불러오기 실패 상태에서 날짜가 바뀌어도 자동으로 다시 읽지 않고, 다음 불러오기는 새 오늘을 쓴다")
  func calendarDayChangedWhenFailedDoesNotRetry() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    self.clock.day = HomeSample.day(2026, 11, 27)
    model.calendarDayChanged()
    await Task.yield()

    #expect(model.content == .loadFailed)
    #expect(store.fetchAllCallCount == 1)

    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(HomeSample.dayShift))
    await retry.value
    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
  }

  @Test("불러오는 중 날짜가 바뀌어도 상태는 loading 그대로이고 추가로 읽지 않는다")
  func calendarDayChangedWhileLoading() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    self.clock.day = HomeSample.day(2026, 11, 27)
    model.calendarDayChanged()

    #expect(model.content == .loading)
    #expect(store.fetchAllCallCount == 1)
    try store.resumeFetch(with: .success(HomeSample.dayShift))
    await task.value
    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
  }

  // MARK: addButtonTapped

  @Test("추가 버튼은 추가 콜백을 한 번 부른다 (불러오기 전이면 기본 폴더 없음)")
  func addButtonCallsCallback() {
    let model = self.makeModel(store: DDayStoreClientFake())

    model.addButtonTapped()

    #expect(self.recorder.addFolderIDs == [nil])
  }

  // MARK: dDayTapped

  @Test("보이는 항목을 누르면 그 디데이로 선택 콜백")
  func dDayTappedSelectsVisible() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))
    await model.onAppear()

    model.dDayTapped(id: HomeSample.id(3))

    #expect(self.recorder.selected == [HomeSample.mixed[2]])
  }

  @Test("없는 id 나 삭제 중인 id 는 선택 콜백을 부르지 않는다")
  func dDayTappedIgnoresHiddenOrUnknown() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    model.dDayTapped(id: HomeSample.id(99))
    let task = model.deleteSwiped(id: HomeSample.id(3))
    model.dDayTapped(id: HomeSample.id(3))

    #expect(self.recorder.selected.isEmpty)
    try await store.waitForPendingDelete(id: HomeSample.id(3))
    try store.resumeDelete(id: HomeSample.id(3), with: .success(()))
    await task?.value
  }

  // MARK: deleteSwiped

  @Test("삭제에 성공하면 목록과 저장소에서 사라진다")
  func deleteSuccess() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()

    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
    #expect(!store.dDays.contains { $0.id == HomeSample.id(3) })
    #expect(!model.isDeleteFailedAlertPresented)
  }

  @Test("삭제에 실패하면 원래 자리로 돌아오고 알림창이 뜬다")
  func deleteSaveFailedRestores() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()

    store.failNextCall(with: .saveFailed)
    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(model.content.ids == HomeSample.mixedOrder)
    #expect(model.content.ids?.firstIndex(of: HomeSample.id(3)) == 1)
    #expect(model.isDeleteFailedAlertPresented)
    #expect(store.dDays.contains { $0.id == HomeSample.id(3) })
  }

  @Test("삭제를 부른 같은 차례에 목록에서 이미 사라진다")
  func deleteHidesSynchronously() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    let task = model.deleteSwiped(id: HomeSample.id(3))

    #expect(task != nil)
    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
    try await store.waitForPendingDelete(id: HomeSample.id(3))
    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
    try store.resumeDelete(id: HomeSample.id(3), with: .success(()))
    await task?.value
  }

  @Test("삭제 중 같은 항목을 다시 삭제하면 무시한다")
  func deleteSameIDTwiceIgnored() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    let first = model.deleteSwiped(id: HomeSample.id(3))
    let second = model.deleteSwiped(id: HomeSample.id(3))

    #expect(second == nil)
    try await store.waitForPendingDelete(id: HomeSample.id(3))
    #expect(store.deleteCallIDs == [HomeSample.id(3)])
    try store.resumeDelete(id: HomeSample.id(3), with: .success(()))
    await first?.value
    #expect(store.deleteCallIDs == [HomeSample.id(3)])
  }

  @Test("겹친 삭제: 실패한 것만 원래 자리로 돌아온다", arguments: [false, true])
  func overlappingDeletes(failureFirst: Bool) async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let failing = HomeSample.id(3)
    let succeeding = HomeSample.id(4)

    let failingTask = model.deleteSwiped(id: failing)
    let succeedingTask = model.deleteSwiped(id: succeeding)
    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != failing && $0 != succeeding })
    try await store.waitForPendingDelete(id: failing)
    try await store.waitForPendingDelete(id: succeeding)

    if failureFirst {
      try store.resumeDelete(id: failing, with: .failure(.saveFailed))
      await failingTask?.value
      try store.resumeDelete(id: succeeding, with: .success(()))
      await succeedingTask?.value
    } else {
      try store.resumeDelete(id: succeeding, with: .success(()))
      await succeedingTask?.value
      try store.resumeDelete(id: failing, with: .failure(.saveFailed))
      await failingTask?.value
    }

    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != succeeding })
    #expect(model.isDeleteFailedAlertPresented)
  }

  @Test("이미 없는 항목(.notFound)은 성공처럼 사라지고 알림창이 없다")
  func deleteNotFoundTreatedAsSuccess() async throws {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()
    try await store.delete(id: HomeSample.id(3))

    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
    #expect(!model.isDeleteFailedAlertPresented)
  }

  @Test("마지막 항목을 지우면 빈 목록")
  func deleteLastItemShowsEmpty() async {
    let only = HomeSample.dDay(1, HomeSample.solar(2026, 12, 25))
    let model = self.makeModel(store: DDayStoreClientFake(dDays: [only]))
    await model.onAppear()

    await model.deleteSwiped(id: only.id)?.value

    #expect(model.content == .loaded([]))
  }

  @Test("삭제 중 날짜가 바뀐 뒤 실패하면 새 오늘 기준 자리로 돌아온다")
  func deleteFailureAfterDayChangeUsesNewDay() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let today = HomeSample.dDay(1, HomeSample.solar(2026, 11, 26)) // 오늘 D-DAY → 다음 날 지난 1일
    let later = HomeSample.dDay(2, HomeSample.solar(2026, 11, 30)) // D-4 → D-3
    let past = HomeSample.dDay(3, HomeSample.solar(2026, 11, 25)) // 지난 1일 → 지난 2일
    try await self.load(model, store, with: .success([today, later, past]))
    #expect(model.content.ids == [today.id, later.id, past.id])

    let task = model.deleteSwiped(id: today.id)
    try await store.waitForPendingDelete(id: today.id)
    self.clock.day = HomeSample.day(2026, 11, 27)
    model.calendarDayChanged()
    #expect(model.content.ids == [later.id, past.id])
    try store.resumeDelete(id: today.id, with: .failure(.saveFailed))
    await task?.value

    #expect(model.content.ids == [later.id, today.id, past.id])
    #expect(model.content.items?[1].status.label == .daysPassed(1))
    #expect(model.isDeleteFailedAlertPresented)
  }

  @Test("목록이 없거나 없는 id 면 삭제하지 않는다")
  func deleteIgnoredWithoutVisibleItem() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)

    // 불러오는 중
    let loading = Task { await model.onAppear() }
    try await store.waitForPendingFetches()
    #expect(model.deleteSwiped(id: HomeSample.id(3)) == nil)
    try store.resumeFetch(with: .failure(.loadFailed))
    await loading.value

    // 불러오기 실패
    #expect(model.content == .loadFailed)
    #expect(model.deleteSwiped(id: HomeSample.id(3)) == nil)

    // 목록이 있는데 없는 id
    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await retry.value
    #expect(model.deleteSwiped(id: HomeSample.id(99)) == nil)

    #expect(store.deleteCallIDs.isEmpty)
    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  // MARK: deleteFailedAlertDismissed

  @Test("삭제 실패 알림창을 닫으면 내려간다")
  func deleteFailedAlertDismissed() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()
    store.failNextCall(with: .saveFailed)
    await model.deleteSwiped(id: HomeSample.id(3))?.value
    #expect(model.isDeleteFailedAlertPresented)

    model.deleteFailedAlertDismissed()

    #expect(!model.isDeleteFailedAlertPresented)
  }
}
