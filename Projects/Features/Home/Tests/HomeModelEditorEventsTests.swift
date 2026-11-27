import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

extension HomeModelTests {
  /// 편집 화면이 돌려준 것 같은 값: 원래 디데이의 id·생성 시각을 유지하고 내용만 바꾼다.
  func edited(_ dDay: DDay, title: String, date: DDayDate) -> DDay {
    DDay(
      id: dDay.id,
      title: title,
      schedule: DDaySchedule(
        date: date,
        repeatRule: dDay.schedule.repeatRule,
        countingStyle: dDay.schedule.countingStyle
      ),
      reminder: dDay.reminder,
      createdAt: dDay.createdAt,
      updatedAt: dDay.updatedAt.addingTimeInterval(1)
    )
  }

  /// 생성 시각을 직접 정한 디데이.
  func dDay(id number: Int, createdAt seconds: TimeInterval, _ date: DDayDate) -> DDay {
    let createdAt = Date(timeIntervalSince1970: seconds)
    return DDay(
      id: HomeSample.id(number),
      title: "디데이 \(number)",
      schedule: DDaySchedule(date: date),
      reminder: .default,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  /// `dDays` 를 fetchAll 순서로 처음 불러왔을 때의 목록 순서.
  func freshOrder(_ dDays: [DDay]) async -> [UUID]? {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: dDays))
    await model.onAppear()
    return model.content.ids
  }

  // MARK: dDaySaved (.loaded)

  @Test("새로 저장한 디데이는 다시 읽지 않고 정렬 자리에 들어간다")
  func dDaySavedInsertsNewSortedWithoutFetch() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let added = HomeSample.dDay(8, HomeSample.solar(2026, 11, 27)) // D-1

    let task = model.dDaySaved(added)

    #expect(task == nil)
    #expect(model.content.ids == [6, 8, 3, 7, 4, 5, 2, 1].map { HomeSample.id($0) })
    let fresh = await self.freshOrder(HomeSample.mixed + [added])
    #expect(model.content.ids == fresh)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("같은 id 를 저장하면 그 항목을 바꾸고 다시 정렬한다")
  func dDaySavedReplacesExisting() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let updated = self.edited(HomeSample.mixed[2], title: "바뀐 제목", date: HomeSample.solar(2026, 11, 25)) // 지난 1일

    model.dDaySaved(updated)

    #expect(model.content.ids == [6, 7, 4, 3, 5, 2, 1].map { HomeSample.id($0) })
    #expect(model.content.items?.count == HomeSample.mixed.count)
    #expect(model.content.items?.first { $0.id == updated.id }?.dDay == updated)
    var expected = HomeSample.mixed
    expected[2] = updated
    let fresh = await self.freshOrder(expected)
    #expect(model.content.ids == fresh)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("저장한 뒤 카드를 누르면 바뀐 값으로 선택한다")
  func dDaySavedThenTappedSelectsNewValue() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))
    await model.onAppear()
    let updated = self.edited(HomeSample.mixed[2], title: "바뀐 제목", date: HomeSample.solar(2026, 12, 1))

    model.dDaySaved(updated)
    model.dDayTapped(id: updated.id)

    #expect(self.recorder.selected == [updated])
  }

  @Test(
    "정렬 키가 같은 항목의 순서는 다시 읽었을 때와 같다 (생성 시각 → id)",
    arguments: [
      (1, 100.0), // 같은 생성 시각, id 가 앞
      (99, 100.0), // 같은 생성 시각, id 가 뒤
      (99, 50.0), // 생성 시각이 앞
      (1, 150.0), // 생성 시각이 뒤
    ]
  )
  func dDaySavedTieOrderMatchesFetch(newID: Int, createdAt: TimeInterval) async {
    let date = HomeSample.solar(2026, 12, 1)
    let existing = [
      self.dDay(id: 50, createdAt: 100, date),
      self.dDay(id: 60, createdAt: 120, date),
    ]
    let added = self.dDay(id: newID, createdAt: createdAt, date)
    let model = self.makeModel(store: DDayStoreClientFake(dDays: existing))
    await model.onAppear()

    model.dDaySaved(added)

    let fresh = await self.freshOrder(existing + [added])

    #expect(model.content.ids == fresh)
  }

  @Test("목록이 있을 때 저장은 nil 을 돌려준다")
  func dDaySavedWhenLoadedReturnsNil() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))
    await model.onAppear()

    #expect(model.dDaySaved(HomeSample.dDay(8, HomeSample.solar(2026, 12, 1))) == nil)
  }

  // MARK: dDayDeleted (.loaded)

  @Test("지운 디데이는 다시 읽지 않고 목록에서 빠진다")
  func dDayDeletedRemoves() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    model.dDayDeleted(id: HomeSample.id(3))

    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
    #expect(store.fetchAllCallCount == 1)
    #expect(store.deleteCallIDs.isEmpty)
  }

  @Test("없는 id 를 지웠다고 받으면 무시한다")
  func dDayDeletedUnknownIDIgnored() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    model.dDayDeleted(id: HomeSample.id(99))

    #expect(model.content.ids == HomeSample.mixedOrder)
    #expect(store.fetchAllCallCount == 1)
  }

  // MARK: 홈 삭제와 겹침

  @Test("홈 삭제 중 편집 화면이 지웠다고 알리면, 홈 삭제가 실패해도 돌아오지 않는다")
  func dDayDeletedWhileHomeDeletingThenFailureDoesNotRestore() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let id = HomeSample.id(3)

    let task = model.deleteSwiped(id: id)
    model.dDayDeleted(id: id)
    try await store.waitForPendingDelete(id: id)
    try store.resumeDelete(id: id, with: .failure(.saveFailed))
    await task?.value

    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != id })
    #expect(model.isDeleteFailedAlertPresented)
  }

  @Test("홈 삭제 중 저장 결과가 오면 계속 숨기고, 삭제 결과에 따라 사라지거나 바뀐 값으로 돌아온다", arguments: [true, false])
  func dDaySavedWhileHomeDeletingStaysHidden(deleteSucceeds: Bool) async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let id = HomeSample.id(3)
    let updated = self.edited(HomeSample.mixed[2], title: "바뀐 제목", date: HomeSample.solar(2026, 11, 29))

    let task = model.deleteSwiped(id: id)
    model.dDaySaved(updated)
    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != id })
    try await store.waitForPendingDelete(id: id)
    try store.resumeDelete(id: id, with: deleteSucceeds ? .success(()) : .failure(.saveFailed))
    await task?.value

    if deleteSucceeds {
      #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != id })
    } else {
      #expect(model.content.ids == HomeSample.mixedOrder)
      #expect(model.content.items?.first { $0.id == id }?.dDay == updated)
    }
  }

  // MARK: 불러오는 중

  @Test("불러오는 중에 온 저장·삭제는 불러온 목록에 적용된다", arguments: [false, true])
  func editsDuringLoadingApplyAfterLoad(fetchIncludesSaved: Bool) async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let saved = HomeSample.dDay(8, HomeSample.solar(2026, 11, 27))
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    #expect(model.dDaySaved(saved) == nil)
    model.dDayDeleted(id: HomeSample.id(2))
    #expect(model.content == .loading)
    // 받은 목록에 저장값이 이미 있으면(옛 값이어도) 저장 결과로 바뀐다.
    let stale = self.edited(saved, title: "옛 제목", date: HomeSample.solar(2026, 12, 25))
    let fetched = HomeSample.mixed + (fetchIncludesSaved ? [stale] : [])
    try store.resumeFetch(with: .success(fetched))
    await task.value

    #expect(model.content.ids == [6, 8, 3, 7, 4, 5, 1].map { HomeSample.id($0) })
    #expect(model.content.items?.first { $0.id == saved.id }?.dDay == saved)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("불러오기가 실패하면 그동안 온 편집 결과는 버리고, 다음 불러오기는 저장소 값 그대로다")
  func editsDuringLoadingDiscardedOnFailure() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()

    model.dDaySaved(HomeSample.dDay(8, HomeSample.solar(2026, 11, 27)))
    model.dDayDeleted(id: HomeSample.id(2))
    try store.resumeFetch(with: .failure(.loadFailed))
    await task.value
    #expect(model.content == .loadFailed)

    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await retry.value

    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  // MARK: 불러오기 실패

  @Test("불러오기 실패 중 저장 결과가 오면 다시 불러와 새 디데이가 보인다")
  func dDaySavedWhenLoadFailedReloads() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))
    let saved = HomeSample.dDay(8, HomeSample.solar(2026, 11, 27))

    let task = model.dDaySaved(saved)

    #expect(task != nil)
    try await store.waitForPendingFetches()
    #expect(model.content == .loading)
    try store.resumeFetch(with: .success(HomeSample.mixed + [saved]))
    await task?.value
    #expect(model.content.ids == [6, 8, 3, 7, 4, 5, 2, 1].map { HomeSample.id($0) })
    #expect(store.fetchAllCallCount == 2)
  }

  @Test("다시 불러오는 중 저장 결과가 오면 더 읽지 않고 불러온 목록에 적용한다")
  func dDaySavedWhileRetryingIsPendingNotRefetch() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))
    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    let saved = HomeSample.dDay(8, HomeSample.solar(2026, 11, 27))

    let task = model.dDaySaved(saved)

    #expect(task == nil)
    #expect(store.fetchAllCallCount == 2)
    try store.resumeFetch(with: .success(HomeSample.mixed))
    await retry.value
    #expect(model.content.ids == [6, 8, 3, 7, 4, 5, 2, 1].map { HomeSample.id($0) })
    #expect(store.fetchAllCallCount == 2)
  }

  @Test("불러오기 실패 중 삭제 결과는 무시한다 (다시 불러오지 않는다)")
  func dDayDeletedWhenLoadFailedIgnored() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    model.dDayDeleted(id: HomeSample.id(3))
    await Task.yield()

    #expect(model.content == .loadFailed)
    #expect(store.fetchAllCallCount == 1)
  }

  @Test("사진이 바뀐 저장 결과가 목록 항목의 photo 에 반영된다")
  func dDaySavedAppliesPhoto() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))
    let original = HomeSample.mixed[2]
    let photo = DDayPhoto(id: HomeSample.id(900), thumbnail: Data([0x01, 0x02]))
    let saved = DDay(
      id: original.id,
      title: original.title,
      schedule: original.schedule,
      reminder: original.reminder,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt.addingTimeInterval(1),
      photo: photo
    )

    #expect(model.dDaySaved(saved) == nil)

    let item = try #require(model.content.items?.first { $0.id == original.id })
    #expect(item.dDay.photo == photo)
    #expect(model.content.ids == HomeSample.mixedOrder)
    #expect(store.fetchAllCallCount == 1)

    let removed = DDay(
      id: original.id,
      title: original.title,
      schedule: original.schedule,
      reminder: original.reminder,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt.addingTimeInterval(2)
    )
    #expect(model.dDaySaved(removed) == nil)
    #expect(model.content.items?.first { $0.id == original.id }?.dDay.photo == nil)
  }
}
