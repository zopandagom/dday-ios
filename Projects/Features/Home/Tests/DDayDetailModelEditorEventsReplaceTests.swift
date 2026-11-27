import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// 새로 저장(`dDaySavedAsNew`)과 삭제(`dDayDeleted`) 이벤트.
extension DDayDetailModelEditorEventsTests {
  // MARK: dDaySavedAsNew

  @Test("지금 디데이를 대신해 새로 저장하면 새 디데이로 바뀌고 새 id 로 압축본을 읽는다")
  func dDaySavedAsNewSwitchesAndLoads() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    let new = self.savedAsNew(photo: HomeSample.photo(3))

    let task = try #require(model.dDaySavedAsNew(new, replacing: self.original.id))

    #expect(model.dDay == new)
    #expect(model.status == DDayStatus(schedule: new.schedule, today: HomeSample.today))
    #expect(model.largePhoto == .loading)
    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: .success(HomeSample.image(3)))
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(3)))
    #expect(store.fetchPhotoCallIDs == [self.original.id, new.id])
  }

  @Test("새로 저장한 디데이에 사진이 없으면 압축본 상태가 없고 읽지 않는다")
  func dDaySavedAsNewWithoutPhoto() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    let new = self.savedAsNew(photo: nil)

    let task = model.dDaySavedAsNew(new, replacing: self.original.id)

    #expect(task == nil)
    #expect(model.dDay == new)
    #expect(model.largePhoto == nil)
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("다른 디데이를 대신한 새로 저장은 무시한다")
  func dDaySavedAsNewOtherIDIgnored() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))

    let task = model.dDaySavedAsNew(self.savedAsNew(photo: HomeSample.photo(3)), replacing: self.withoutPhoto.id)

    #expect(task == nil)
    #expect(model.dDay == self.original)
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }

  @Test("읽는 중 새로 저장하면 옛 id 의 결과는 버린다")
  func staleResultAfterSavedAsNewIsDropped() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)
    let newDDay = self.savedAsNew(photo: HomeSample.photo(3))
    let new = try #require(model.dDaySavedAsNew(newDDay, replacing: self.original.id))
    try await store.waitForPendingFetchPhotos(2)

    try store.resumeFetchPhoto(at: 0, with: .success(HomeSample.image(1)))
    await old.value
    #expect(model.largePhoto == .loading)
    try store.resumeFetchPhoto(at: 0, with: .success(HomeSample.image(3)))
    await new.value

    #expect(model.largePhoto == .loaded(HomeSample.image(3)))
    #expect(store.fetchPhotoCallIDs == [self.original.id, newDDay.id])
  }

  @Test("읽기 실패 상태에서 사진 있는 새 디데이로 새로 저장하면 새 id 로 읽는다")
  func dDaySavedAsNewAfterFailureLoads() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .failure(.loadFailed))
    let new = self.savedAsNew(photo: HomeSample.photo(3))

    let task = try #require(model.dDaySavedAsNew(new, replacing: self.original.id))

    try await store.waitForPendingFetchPhotos()
    try store.resumeFetchPhoto(with: .success(HomeSample.image(3)))
    await task.value
    #expect(model.largePhoto == .loaded(HomeSample.image(3)))
    #expect(store.fetchPhotoCallIDs == [self.original.id, new.id])
  }

  // MARK: dDayDeleted

  @Test("지금 디데이가 지워지면 지워짐 상태가 되고 내용·압축본은 그대로, 다른 디데이면 그대로")
  func dDayDeletedMarksRemoved() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))

    model.dDayDeleted(id: self.withoutPhoto.id)
    #expect(model.isRemoved == false)

    model.dDayDeleted(id: self.original.id)

    #expect(model.isRemoved == true)
    #expect(model.dDay == self.original)
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
  }

  @Test("읽는 중 지워지면 늦게 온 결과를 반영하지 않는다")
  func staleResultAfterDeletedIsDropped() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    let old = try await self.startAppear(model, store)

    model.dDayDeleted(id: self.original.id)
    try store.resumeFetchPhoto(with: .success(HomeSample.image(1)))
    await old.value

    #expect(model.isRemoved == true)
    #expect(model.largePhoto == .loading)
  }

  @Test("지워진 뒤의 저장·새로 저장은 무시하고, 다시 지워져도 그대로")
  func editorEventsAfterRemovedIgnored() async throws {
    let store = ControlledPhotoStore()
    let model = self.makeModel(self.original, store: store)
    try await self.finishAppear(model, store, with: .success(HomeSample.image(1)))
    model.dDayDeleted(id: self.original.id)

    let saved = model.dDaySaved(self.edited(self.original, photo: HomeSample.photo(2)))
    let savedAsNew = model.dDaySavedAsNew(self.savedAsNew(photo: HomeSample.photo(3)), replacing: self.original.id)
    model.dDayDeleted(id: self.original.id)

    #expect(saved == nil)
    #expect(savedAsNew == nil)
    #expect(model.isRemoved == true)
    #expect(model.dDay == self.original)
    #expect(model.largePhoto == .loaded(HomeSample.image(1)))
    await Task.yield()
    #expect(store.fetchPhotoCallIDs.count == 1)
  }
}
