import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// 스와이프 삭제 성공 콜백(`onDDayDeleted`): App 이 알림을 다시 예약하는 시점.
extension HomeModelTests {
  @Test("스와이프 삭제에 성공하면 그 id 로 한 번 알린다")
  func deleteSuccessCallsBack() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))
    await model.onAppear()

    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(self.recorder.deletedIDs == [HomeSample.id(3)])
  }

  @Test("저장소에 이미 없으면(.notFound) 성공처럼 한 번 알린다")
  func deleteNotFoundCallsBack() async throws {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()
    try await store.delete(id: HomeSample.id(3))

    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(self.recorder.deletedIDs == [HomeSample.id(3)])
  }

  @Test("삭제에 실패하면 알리지 않는다 (항목 복원·알림창)")
  func deleteFailureDoesNotCallBack() async {
    let store = DDayStoreClientFake(dDays: HomeSample.mixed)
    let model = self.makeModel(store: store)
    await model.onAppear()

    store.failNextCall(with: .saveFailed)
    await model.deleteSwiped(id: HomeSample.id(3))?.value

    #expect(self.recorder.deletedIDs.isEmpty)
    #expect(model.isDeleteFailedAlertPresented)
    #expect(model.content.ids == HomeSample.mixedOrder)
  }

  @Test("저장소가 끝나기 전에는 알리지 않는다")
  func deleteCallsBackOnlyAfterStoreFinishes() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    let task = model.deleteSwiped(id: HomeSample.id(3))
    try await store.waitForPendingDelete(id: HomeSample.id(3))
    #expect(self.recorder.deletedIDs.isEmpty)

    try store.resumeDelete(id: HomeSample.id(3), with: .success(()))
    await task?.value
    #expect(self.recorder.deletedIDs == [HomeSample.id(3)])
  }

  @Test("무시되는 스와이프(삭제 중 같은 항목·없는 id)는 알리지 않는다")
  func ignoredSwipesDoNotCallBack() async throws {
    let store = ControlledDDayStore()
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(HomeSample.mixed))

    #expect(model.deleteSwiped(id: HomeSample.id(99)) == nil)
    let first = model.deleteSwiped(id: HomeSample.id(3))
    #expect(model.deleteSwiped(id: HomeSample.id(3)) == nil)
    try await store.waitForPendingDelete(id: HomeSample.id(3))
    try store.resumeDelete(id: HomeSample.id(3), with: .success(()))
    await first?.value

    #expect(self.recorder.deletedIDs == [HomeSample.id(3)])
  }

  @Test("편집 결과·폴더 관리로 온 dDayDeleted(id:) 는 알리지 않는다")
  func dDayDeletedDoesNotCallBack() async {
    let model = self.makeModel(store: DDayStoreClientFake(dDays: HomeSample.mixed))
    await model.onAppear()

    model.dDayDeleted(id: HomeSample.id(3))

    #expect(self.recorder.deletedIDs.isEmpty)
    #expect(model.content.ids == HomeSample.mixedOrder.filter { $0 != HomeSample.id(3) })
  }
}
