import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

// MARK: - Tests

@MainActor
struct HomeModelTests {
  let clock = TestDayClock()
  let recorder = CallbackRecorder()

  func makeModel(store: any DDayStoreClient) -> HomeModel {
    let clock = self.clock
    let recorder = self.recorder
    return HomeModel(
      store: store,
      today: { clock.day },
      onAddTapped: { recorder.addFolderIDs.append($0) },
      onDDaySelected: { recorder.selected.append($0) },
      onFolderManagerTapped: { recorder.folderManagerTapCount += 1 }
    )
  }

  /// Controlled 저장소로 첫 불러오기를 `result` 로 끝낸다.
  func load(_ model: HomeModel, _ store: ControlledDDayStore, with result: Result<
    [DDay],
    DDayStoreError
  >) async throws {
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: result)
    await task.value
  }

  func expectedStatuses(_ dDays: [DDay], today: CalendarDay) -> [DDayStatus] {
    dDays.map { DDayStatus(schedule: $0.schedule, today: today) }
  }

  // MARK: onAppear

  @Test("불러오면 Core 정렬 순서로 오늘 기준 상태와 함께 보인다")
  func onAppearLoadsSortedItems() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))

    await model.onAppear()

    #expect(model.content.ids == HomeSample.mixedOrder)
    let core = DDayListOrder.entries(HomeSample.mixed, today: HomeSample.today, schedule: \.schedule)
    #expect(model.content.ids == core.map(\.item.id))
    #expect(model.content.items?.map(\.status) == core.map(\.status))
  }

  @Test("빈 저장소면 빈 목록")
  func onAppearEmpty() async {
    let model = self.makeModel(store: DDayStoreClientFake())

    await model.onAppear()

    #expect(model.content == .loaded([]))
  }

  @Test("불러오기에 실패하면 loadFailed")
  func onAppearFailure() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    store.failNextCall(with: .loadFailed)
    let model = self.makeModel(store: store)

    await model.onAppear()

    #expect(model.content == .loadFailed)
  }

  @Test("불러오는 중 다시 나타나도 한 번만 읽는다")
  func onAppearWhileLoadingFetchesOnce() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    await model.onAppear()

    #expect(store.fetchAllCallCount == 1)
    #expect(model.content == .loading)
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await task.value
    #expect(model.content.ids == HomeSample.mixedOrder)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("불러온 뒤 다시 나타나도 다시 읽지 않는다")
  func onAppearAfterLoadedDoesNotRefetch() async throws {
    let store = DDayStoreClientFake(dDays: HomeSample.dayShift)
    let model = self.makeModel(store: store)
    await model.onAppear()
    let before = model.content

    _ = try await store.add(DDayDraft(title: "새 디데이", schedule: DDaySchedule(date: HomeSample.solar(2026, 12, 1))))
    await model.onAppear()

    #expect(model.content == before)
    #expect(model.content.items?.count == HomeSample.dayShift.count)
  }

  @Test("불러오는 중 날짜가 바뀌면 완료된 목록은 새 오늘 기준")
  func dayChangeWhileLoadingUsesNewDay() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    self.clock.day = HomeSample.day(2026, 11, 27)
    model.calendarDayChanged()
    #expect(model.content == .loading)
    try store.resumeFetch(with: .success(HomeSample.dayShift))
    await task.value

    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
    #expect(
      model.content.items?.map(\.status)
        == self.expectedStatuses(
          [10, 12, 11].compactMap { number in HomeSample.dayShift.first { $0.id == HomeSample.id(number) } },
          today: HomeSample.day(2026, 11, 27)
        )
    )
  }

  @Test("불러오는 중 Task 가 취소돼도 결과를 반영한다")
  func cancelledLoadStillApplies() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    task.cancel()
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await task.value

    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  // MARK: retryButtonTapped

  @Test("실패 뒤 다시 시도하면 목록이 보인다")
  func retryAfterFailureLoads() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    store.failNextCall(with: .loadFailed)
    let model = self.makeModel(store: store)
    await model.onAppear()

    await model.retryButtonTapped()

    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("다시 시도 중에는 loading, 또 실패하면 loadFailed")
  func retryShowsLoadingThenFailsAgain() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))
    #expect(model.content == .loadFailed)

    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    #expect(model.content == .loading)
    try store.resumeFetch(with: .failure(.loadFailed))
    await retry.value

    #expect(model.content == .loadFailed)
    #expect(store.fetchAllCallCount == 2)
  }

  @Test("다시 시도 중 또 누르면 추가로 읽지 않는다")
  func retryWhileRetryingFetchesOnce() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    await model.retryButtonTapped()

    #expect(store.fetchAllCallCount == 2)
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await retry.value
    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("목록이 있을 때 다시 시도는 아무것도 하지 않는다")
  func retryWhenLoadedDoesNothing() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let before = model.content

    await model.retryButtonTapped()

    #expect(model.content == before)
    #expect(store.fetchAllCallCount == 1)
  }

  // MARK: sceneBecameActive

  @Test("앱 복귀 때 오늘이 바뀌었으면 다시 정렬하고 저장소는 다시 읽지 않는다")
  func sceneActiveReordersOnNewDay() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.dayShift))
    #expect(model.content.ids == [11, 10, 12].map { HomeSample.id($0) })

    self.clock.day = HomeSample.day(2026, 11, 27)
    await model.sceneBecameActive()

    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
    #expect(model.content.items?.first?.status.label == .dDay)
    #expect(model.content.items?.last?.status.group == .passed)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("앱 복귀 때 오늘이 같으면 그대로")
  func sceneActiveSameDayKeepsList() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.dayShift))
    let before = model.content

    await model.sceneBecameActive()

    #expect(model.content == before)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("불러오기 실패 상태에서 앱 복귀하면 버튼 없이 다시 불러온다")
  func sceneActiveRetriesAfterFailure() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    store.failNextCall(with: .loadFailed)
    let model = self.makeModel(store: store)
    await model.onAppear()
    #expect(model.content == .loadFailed)

    await model.sceneBecameActive()

    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("앱 복귀 재시도가 또 실패하면 loadFailed, 복귀마다 한 번씩 읽는다")
  func sceneActiveRetryFailsAgain() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    let first = Task { await model.sceneBecameActive() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .failure(.loadFailed))
    await first.value
    #expect(model.content == .loadFailed)
    #expect(store.fetchAllCallCount == 2)

    let second = Task { await model.sceneBecameActive() }
    try await store.waitForPendingFetches()
    #expect(store.fetchAllCallCount == 3)
    try store.resumeFetch(with: .failure(.loadFailed))
    await second.value
    #expect(model.content == .loadFailed)
  }

  @Test("첫 불러오기 중 앱 복귀는 추가로 읽지 않는다")
  func sceneActiveWhileLoadingDoesNotFetch() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    await model.sceneBecameActive()

    #expect(store.fetchAllCallCount == 1)
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await task.value
    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("앱 복귀 재시도 중 다시 시도를 눌러도 추가로 읽지 않는다")
  func retryDuringSceneActiveRetry() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    let scene = Task { await model.sceneBecameActive() }
    try await store.waitForPendingFetches()
    await model.retryButtonTapped()

    #expect(store.fetchAllCallCount == 2)
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await scene.value
    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("불러오기 실패 상태에서 날이 바뀐 채 앱 복귀하면 재시도 결과가 새 오늘 기준")
  func sceneActiveRetryUsesNewDay() async {
    let store = DDayStoreClientFake(dDays: HomeSample.dayShift)
    store.failNextCall(with: .loadFailed)
    let model = self.makeModel(store: store)
    await model.onAppear()

    self.clock.day = HomeSample.day(2026, 11, 27)
    await model.sceneBecameActive()

    #expect(model.content.ids == [10, 12, 11].map { HomeSample.id($0) })
    #expect(model.content.items?.allSatisfy {
      $0.status == DDayStatus(schedule: $0.dDay.schedule, today: HomeSample.day(2026, 11, 27))
    } == true)
  }
}
