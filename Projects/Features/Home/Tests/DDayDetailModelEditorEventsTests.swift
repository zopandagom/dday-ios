import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// 편집 결과(`dDaySaved`·`dDaySavedAsNew`·`dDayDeleted`)와 압축본 읽기의 겹침.
@MainActor
struct DDayDetailModelEditorEventsTests {
  let clock = TestDayClock()
  let recorder = CallbackRecorder()

  /// 사진 있는 디데이 (오늘 기준 D-1).
  let original = HomeSample.dDay(1, HomeSample.solar(2026, 11, 27), photo: HomeSample.photo(1))
  /// 사진 없는 디데이.
  let withoutPhoto = HomeSample.dDay(2, HomeSample.solar(2026, 11, 27))

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

  /// 읽기를 시작하고 저장소에서 멈출 때까지 기다린 뒤 그 Task 를 돌려준다.
  func startAppear(_ model: DDayDetailModel, _ store: ControlledPhotoStore) async throws -> Task<Void, Never> {
    let task = try #require(model.onAppear())
    try await store.waitForPendingFetchPhotos(1)
    return task
  }

  /// `onAppear` 의 읽기를 `result` 로 끝낸다.
  func finishAppear(
    _ model: DDayDetailModel,
    _ store: ControlledPhotoStore,
    with result: Result<Data?, DDayStoreError>
  ) async throws {
    let task = try await self.startAppear(model, store)
    try store.resumeFetchPhoto(with: result)
    await task.value
  }

  func edited(_ dDay: DDay, title: String = "바뀐 제목", date: DDayDate? = nil, photo: DDayPhoto?) -> DDay {
    DDayDetailModelTests.edited(dDay, title: title, date: date, photo: photo)
  }

  /// 원래 디데이 대신 새로 저장된 디데이 (새 id).
  func savedAsNew(photo: DDayPhoto?) -> DDay {
    HomeSample.dDay(3, HomeSample.solar(2026, 12, 1), photo: photo)
  }

  // MARK: dDaySaved

  @Test("같은 디데이·같은 사진 저장은 내용과 카운트만 바꾸고 압축본을 다시 읽지 않는다")
  func dDaySavedSamePhotoKeepsLargePhoto() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    let updated = self.edited(self.original, date: HomeSample.solar(2026, 11, 26), photo: self.original.photo)

    let task = model.dDaySaved(updated)

    #expect(task == nil)
    #expect(model.dDay == updated)
    #expect(model.status.label == .dDay)
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("사진을 바꿔 저장하면 같은 차례에 읽는 중이 되고 새 압축본을 읽는다")
  func dDaySavedNewPhotoReloads() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    let updated = self.edited(self.original, photo: HomeSample.photo(2))

    let task = try #require(model.dDaySaved(updated))

    #expect(model.largePhoto == .loading)
    #expect(model.dDay == updated)
    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: .success(HomeSample.image(2)))
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
    #expect(store.fetchPhotoCallIDs == [self.original.id, self.original.id])
  }

  @Test("사진을 지워 저장하면 압축본 상태가 없어지고 읽지 않는다")
  func dDaySavedRemovedPhoto() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))

    let task = model.dDaySaved(self.edited(self.original, photo: nil))

    #expect(task == nil)
    #expect(model.largePhoto == nil)
    #expect(model.dDay.photo == nil)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("사진 없던 디데이에 사진을 붙여 저장하면 압축본을 읽는다")
  func dDaySavedAddedPhoto() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.withoutPhoto, store: store)

    let task = try #require(model.dDaySaved(self.edited(self.withoutPhoto, photo: HomeSample.photo(2))))

    #expect(model.largePhoto == .loading)
    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: .success(HomeSample.image(2)))
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
    #expect(store.fetchPhotoCallIDs == [self.withoutPhoto.id])
  }

  @Test("다른 디데이의 저장은 무시한다")
  func dDaySavedOtherIDIgnored() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    let other = self.edited(self.withoutPhoto, photo: HomeSample.photo(2))

    let task = model.dDaySaved(other)

    #expect(task == nil)
    #expect(model.dDay == self.original)
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("읽기 실패 상태에서 사진을 바꿔 저장하면 새로 읽는다")
  func dDaySavedNewPhotoAfterFailure() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .failure(.loadFailed))

    let task = try #require(model.dDaySaved(self.edited(self.original, photo: HomeSample.photo(2))))

    #expect(model.largePhoto == .loading)
    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: .success(HomeSample.image(2)))
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
  }

  @Test("읽는 중 사진이 바뀌면 옛 읽기가 나중에 끝나도 버리고 새 결과만 남긴다")
  func staleResultArrivingLaterIsDropped() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)
    let new = try #require(model.dDaySaved(self.edited(self.original, photo: HomeSample.photo(2))))
    try await store.waitForPendingFetchPhotos(2)

    try store.resumeFetchPhoto(at: 1, with: .success(HomeSample.image(2)))
    await new.value
    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
    try store.resumeFetchPhoto(at: 0, with: .success(HomeSample.image(1)))
    await old.value

    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
  }

  @Test("읽는 중 사진이 바뀌면 옛 읽기가 먼저 끝나도 반영하지 않고 새 결과를 기다린다")
  func staleResultArrivingFirstIsDropped() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)
    let new = try #require(model.dDaySaved(self.edited(self.original, photo: HomeSample.photo(2))))
    try await store.waitForPendingFetchPhotos(2)

    try store.resumeFetchPhoto(at: 0, with: .success(HomeSample.image(1)))
    await old.value
    #expect(model.largePhoto == .loading)
    try store.resumeFetchPhoto(at: 0, with: .success(HomeSample.image(2)))
    await new.value

    #expect(model.largePhoto == .loaded(HomeSample.image(2)))
  }

  @Test("읽는 중 사진을 지우면 옛 결과가 와도 압축본 상태가 없다")
  func staleResultAfterPhotoRemovedIsDropped() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)

    #expect(model.dDaySaved(self.edited(self.original, photo: nil)) == nil)
    #expect(model.largePhoto == nil)
    try store.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await old.value

    #expect(model.largePhoto == nil)
  }

  @Test("읽는 중 제목만 바뀌면 다시 읽지 않고 진행 중인 결과를 반영한다")
  func titleOnlyChangeWhileLoadingKeepsRead() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)
    let updated = self.edited(self.original, photo: self.original.photo)

    #expect(model.dDaySaved(updated) == nil)
    #expect(model.largePhoto == .loading)
    try store.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await old.value

    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    #expect(model.dDay == updated)
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("읽기 실패 상태에서 사진이 같은 저장은 실패를 유지하고 다시 읽지 않는다")
  func dDaySavedSamePhotoAfterFailureKeepsFailed() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .failure(.loadFailed))

    let task = model.dDaySaved(self.edited(self.original, photo: self.original.photo))

    #expect(task == nil)
    #expect(model.largePhoto == .failed)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }
}
