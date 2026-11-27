import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

// MARK: - Tests

@MainActor
struct DDayDetailModelTests {
  let clock = TestDayClock()
  let recorder = CallbackRecorder()

  /// 사진 있는 디데이 (오늘 기준 D-1).
  let withPhoto = HomeSample.dDay(1, HomeSample.solar(2026, 11, 27), photo: HomeSample.photo(1))
  /// 사진 없는 디데이 (오늘 기준 D-1).
  let withoutPhoto = HomeSample.dDay(2, HomeSample.solar(2026, 11, 27))

  /// `onEditTapped` 는 `recorder.selected` 에 기록한다.
  func makeModel(_ dDay: DDay, store: any DDayStoreClient) -> DDayDetailModel {
    let clock = self.clock
    let recorder = self.recorder
    return DDayDetailModel(
      dDay: dDay,
      store: store,
      today: { clock.day },
      onEditTapped: { recorder.selected.append($0) }
    )
  }

  /// Controlled 저장소로 `onAppear` 의 읽기를 `result` 로 끝낸다.
  func finishAppear(
    _ model: DDayDetailModel,
    _ store: ControlledPhotoStore,
    with result: Result<Data?, DDayStoreError>
  ) async throws {
    let task = try #require(model.onAppear())
    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: result)
    await task.value
  }

  // MARK: init

  @Test("사진 있는 디데이로 만들면 압축본은 아직 읽지 않았고 카운트는 주입한 오늘 기준")
  func initWithPhoto() {
    let model = self.makeModel(self.withPhoto, store: DDayStoreClientFake())

    #expect(model.largePhoto == .notLoaded)
    #expect(model.dDay == self.withPhoto)
    #expect(model.status == DDayStatus(schedule: self.withPhoto.schedule, today: HomeSample.today))
    #expect(model.status.label == .daysLeft(1))
    #expect(model.isRemoved == false)
  }

  @Test("사진 없는 디데이는 압축본 상태가 없다")
  func initWithoutPhoto() {
    let model = self.makeModel(self.withoutPhoto, store: DDayStoreClientFake())

    #expect(model.largePhoto == nil)
  }

  // MARK: onAppear

  @Test("나타나면 그 디데이 id 로 압축본을 읽는다")
  func onAppearLoadsLargePhoto() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)

    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))

    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    #expect(store.fetchPhotoCallIDs == [self.withPhoto.id])
  }

  @Test("나타나는 같은 차례에 읽는 중으로 바뀐다")
  func onAppearMarksLoadingImmediately() async throws {
    let store = DDayStoreClientFake(dDays: [self.withPhoto], photoImages: [self.withPhoto.id: HomeSample.image(1)])
    let model = self.makeModel(self.withPhoto, store: store)

    let task = try #require(model.onAppear())

    #expect(model.largePhoto == .loading)
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
  }

  @Test("사진이 없으면 나타나도 읽지 않는다")
  func onAppearWithoutPhotoDoesNotRead() async {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withoutPhoto, store: store)

    let task = model.onAppear()

    #expect(task == nil)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.isEmpty)
    #expect(model.largePhoto == nil)
  }

  @Test("압축본이 nil 이면 없음 상태")
  func onAppearNilIsUnavailable() async {
    // 압축본을 넣지 않은 Fake 는 사진이 있어도 nil 을 돌려준다.
    let model = self.makeModel(self.withPhoto, store: DDayStoreClientFake(dDays: [self.withPhoto]))

    await model.onAppear()?.value

    #expect(model.largePhoto == .unavailable)
  }

  @Test("읽기가 던지면 실패 상태", arguments: [DDayStoreError.loadFailed, .notFound])
  func onAppearThrowsIsFailed(error: DDayStoreError) async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)

    try await self.finishAppear(model, store, with: .failure(error))

    #expect(model.largePhoto == .failed)
  }

  @Test("읽는 중에 다시 나타나도 다시 읽지 않는다")
  func onAppearWhileLoadingDoesNotReadAgain() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)
    let first = try #require(model.onAppear())
    try await store.waitForPendingFetchPhotos()

    let second = model.onAppear()

    #expect(second == nil)
    #expect(store.fetchPhotoCallIDs.count == 1)
    try store.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await first.value
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test(
    "읽은 뒤에는 다시 나타나도 다시 읽지 않는다",
    arguments: [
      Result<Data?, DDayStoreError>.success(HomeSample.image(1)),
      .success(nil),
      .failure(.loadFailed),
    ]
  )
  func onAppearAfterFinishedDoesNotReadAgain(result: Result<Data?, DDayStoreError>) async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)
    try await self.finishAppear(model, store, with: result)
    let before = model.largePhoto

    let task = model.onAppear()

    #expect(task == nil)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
    #expect(model.largePhoto == before)
  }

  // MARK: sceneBecameActive

  @Test("앱 복귀 때 실패한 읽기만 한 번 다시 읽고, 그 사이 또 불러도 호출은 하나")
  func sceneBecameActiveRetriesFailedOnce() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)
    try await self.finishAppear(model, store, with: .failure(.loadFailed))

    let retry = try #require(model.sceneBecameActive())
    #expect(model.largePhoto == .loading)
    let again = model.sceneBecameActive()

    #expect(again == nil)
    try await store.waitForPendingFetchPhotos()
    #expect(store.fetchPhotoCallIDs == [self.withPhoto.id, self.withPhoto.id])
    try store.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await retry.value
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    #expect(store.pendingFetchPhotoCount == 0)
  }

  @Test("앱 복귀 때 실패가 아니면 읽지 않는다 (읽기 전·읽는 중·읽음·없음·사진 없음)")
  func sceneBecameActiveDoesNotReadUnlessFailed() async throws {
    // 읽기 전
    let notLoadedStore = ControlledPhotoStore()
    let notLoaded = self.makeModel(self.withPhoto, store: notLoadedStore)
    #expect(notLoaded.sceneBecameActive() == nil)
    #expect(notLoaded.largePhoto == .notLoaded)

    // 읽는 중
    let loadingStore = ControlledPhotoStore()
    let loading = self.makeModel(self.withPhoto, store: loadingStore)
    let task = try #require(loading.onAppear())
    try await loadingStore.waitForPendingFetchPhotos()
    #expect(loading.sceneBecameActive() == nil)
    #expect(loadingStore.fetchPhotoCallIDs.count == 1)
    try loadingStore.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await task.value

    // 읽음
    #expect(loading.sceneBecameActive() == nil)

    // 없음
    let unavailableStore = ControlledPhotoStore()
    let unavailable = self.makeModel(self.withPhoto, store: unavailableStore)
    try await self.finishAppear(unavailable, unavailableStore, with: .success(nil))
    #expect(unavailable.sceneBecameActive() == nil)

    // 사진 없음
    let noPhotoStore = ControlledPhotoStore()
    let noPhoto = self.makeModel(self.withoutPhoto, store: noPhotoStore)
    #expect(noPhoto.sceneBecameActive() == nil)

    await Task.yield()
    #expect(notLoadedStore.fetchPhotoCallIDs.isEmpty)
    #expect(loadingStore.fetchPhotoCallIDs.count == 1)
    #expect(unavailableStore.fetchPhotoCallIDs.count == 1)
    #expect(noPhotoStore.fetchPhotoCallIDs.isEmpty)
    #expect(loading.largePhoto == .loaded(HomeSample.image(1)))
    #expect(unavailable.largePhoto == .unavailable)
  }

  // MARK: 오늘 갱신

  @Test("오늘이 바뀌면 카운트를 다시 계산하고, 같으면 그대로 (저장소는 읽지 않는다)")
  func dayChangeRecomputesStatus() async {
    let store = ControlledPhotoStore()
    let byCalendar = self.makeModel(self.withPhoto, store: store)
    let byScene = self.makeModel(self.withoutPhoto, store: store)

    byCalendar.calendarDayChanged()
    byScene.sceneBecameActive()
    #expect(byCalendar.status.label == .daysLeft(1))
    #expect(byScene.status.label == .daysLeft(1))

    self.clock.day = HomeSample.day(2026, 11, 27)
    byCalendar.calendarDayChanged()
    byScene.sceneBecameActive()

    #expect(byCalendar.status.label == .dDay)
    #expect(byCalendar.status == DDayStatus(schedule: self.withPhoto.schedule, today: self.clock.day))
    #expect(byScene.status.label == .dDay)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.isEmpty)
    #expect(byCalendar.largePhoto == .notLoaded)
  }

  // MARK: editButtonTapped

  @Test("편집 버튼은 지금 디데이로 편집을 연다 (저장 결과 뒤면 바뀐 값)")
  func editButtonPassesCurrentDDay() {
    let model = self.makeModel(self.withoutPhoto, store: DDayStoreClientFake())

    model.editButtonTapped()
    #expect(self.recorder.selected == [self.withoutPhoto])

    let edited = DDayDetailModelTests.edited(self.withoutPhoto, title: "바뀐 제목", photo: nil)
    model.dDaySaved(edited)
    model.editButtonTapped()

    #expect(self.recorder.selected == [self.withoutPhoto, edited])
  }

  @Test("지워진 뒤에는 편집·나타남·앱 복귀·날짜 변경이 아무것도 하지 않는다")
  func eventsAfterRemovedDoNothing() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withPhoto, store: store)
    model.dDayDeleted(id: self.withPhoto.id)
    self.clock.day = HomeSample.day(2026, 11, 27)

    model.editButtonTapped()
    let appear = model.onAppear()
    let scene = model.sceneBecameActive()
    model.calendarDayChanged()

    #expect(self.recorder.selected.isEmpty)
    #expect(appear == nil)
    #expect(scene == nil)
    #expect(model.status.label == .daysLeft(1))
    #expect(model.largePhoto == .notLoaded)

    // 실패 상태에서 지워져도 앱 복귀가 다시 읽지 않는다.
    let failedStore = ControlledPhotoStore()
    let failed = self.makeModel(self.withPhoto, store: failedStore)
    try await self.finishAppear(failed, failedStore, with: .failure(.loadFailed))
    failed.dDayDeleted(id: self.withPhoto.id)
    #expect(failed.sceneBecameActive() == nil)
    #expect(failed.largePhoto == .failed)

    await Task.yield()
    #expect(store.fetchPhotoCallIDs.isEmpty)
    #expect(failedStore.fetchPhotoCallIDs.count == 1)
  }
}

extension DDayDetailModelTests {
  /// 편집 화면이 돌려준 것 같은 값: 원래 디데이의 id·생성 시각·일정을 유지하고 제목과 사진만 바꾼다 (`date` 를 주면 날짜도).
  static func edited(_ dDay: DDay, title: String, date: DDayDate? = nil, photo: DDayPhoto?) -> DDay {
    DDay(
      id: dDay.id,
      title: title,
      schedule: DDaySchedule(
        date: date ?? dDay.schedule.date,
        repeatRule: dDay.schedule.repeatRule,
        countingStyle: dDay.schedule.countingStyle
      ),
      reminder: dDay.reminder,
      createdAt: dDay.createdAt,
      updatedAt: dDay.updatedAt.addingTimeInterval(1),
      photo: photo
    )
  }
}
