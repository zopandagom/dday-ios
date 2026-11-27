import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import FolderManagerFeature

/// 폴더 삭제 (밀기·확인·실패·중복 호출). 그 밖의 FolderManagerModel 테스트는 FolderManagerModelTests.swift.
@MainActor
struct FolderManagerModelDeletionTests {
  let recorder = CallbackRecorder()

  @Test("밀기: 확인창에 폴더와 디데이 수(없으면 0)")
  func deleteSwipedPresentsConfirmation() {
    let model = self.recorder.makeManager(
      dDayCounts: [FolderSample.birthday.id: 3],
      store: DDayStoreClientFake()
    )

    model.deleteSwiped(id: FolderSample.birthday.id)
    #expect(model.pendingDeletion == .init(folder: FolderSample.birthday, dDayCount: 3))
    #expect(model.isDeleteConfirmationPresented)

    model.deleteSwiped(id: FolderSample.family.id)
    #expect(model.pendingDeletion == .init(folder: FolderSample.family, dDayCount: 0))

    model.deleteSwiped(id: FolderSample.id(9999))
    #expect(model.pendingDeletion?.folder == FolderSample.family)
  }

  @Test("미분류로 옮기며 삭제: 같은 차례에 숨기고 성공하면 foldersChanged 만, 디데이는 Fake 에서 미분류")
  func deleteMoveToUnfiled() async throws {
    let dDay = FolderSample.dDay(1, folderID: FolderSample.birthday.id)
    let store = DDayStoreClientFake(dDays: [dDay], folders: FolderSample.defaults)
    let model = self.recorder.makeManager(dDayCounts: [FolderSample.birthday.id: 1], store: store)
    model.deleteSwiped(id: FolderSample.birthday.id)

    let task = try #require(model.deleteConfirmed(id: FolderSample.birthday.id, dDays: .moveToUnfiled))

    let remaining = Array(FolderSample.defaults.dropFirst())
    #expect(model.folders == remaining)
    #expect(model.phase == .deleting(FolderSample.birthday.id))
    #expect(!model.isDeleteConfirmationPresented)
    await task.value

    #expect(model.phase == .idle)
    #expect(model.dDayCounts[FolderSample.birthday.id] == nil)
    #expect(self.recorder.events == [.foldersChanged(remaining)])
    #expect(store.dDays.map(\.folderID) == [nil])
    #expect(store.folders == remaining)
  }

  @Test("디데이도 함께 삭제: 지운 디데이마다 dDayDeleted → foldersChanged 순서, 수에서 키가 빠진다")
  func deleteWithDDays() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(
      dDayCounts: [FolderSample.birthday.id: 2, FolderSample.family.id: 1],
      store: store
    )

    let task = try #require(model.deleteConfirmed(id: FolderSample.birthday.id, dDays: .delete))
    try await store.waitForPendingDelete()
    #expect(store.calls == [.delete(FolderSample.birthday.id, .delete)])
    try store.resumeDelete(with: .success([FolderSample.id(1), FolderSample.id(2)]))
    await task.value

    let remaining = Array(FolderSample.defaults.dropFirst())
    #expect(self.recorder.events == [
      .dDayDeleted(FolderSample.id(1)),
      .dDayDeleted(FolderSample.id(2)),
      .foldersChanged(remaining),
    ])
    #expect(model.dDayCounts == [FolderSample.family.id: 1])
  }

  @Test("디데이도 함께 삭제: Fake 에서 그 폴더 디데이만 빠진다")
  func deleteWithDDaysUpdatesFake() async {
    let inside = FolderSample.dDay(1, folderID: FolderSample.birthday.id)
    let outside = FolderSample.dDay(2, folderID: FolderSample.family.id)
    let store = DDayStoreClientFake(dDays: [inside, outside], folders: FolderSample.defaults)
    let model = self.recorder.makeManager(store: store)

    await model.deleteConfirmed(id: FolderSample.birthday.id, dDays: .delete)?.value

    #expect(store.dDays == [outside])
    #expect(self.recorder.events.first == .dDayDeleted(inside.id))
  }

  @Test("삭제 실패: 같은 자리로 돌아오고 알림, 콜백 없음")
  func deleteFailureRestores() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(dDayCounts: [FolderSample.family.id: 1], store: store)

    let task = try #require(model.deleteConfirmed(id: FolderSample.family.id, dDays: .delete))
    try await store.waitForPendingDelete()
    try store.resumeDelete(with: .failure(.saveFailed))
    await task.value

    #expect(model.folders == FolderSample.defaults)
    #expect(model.phase == .idle)
    #expect(model.alert == .deleteFailed)
    #expect(model.isAlertPresented)
    #expect(model.dDayCounts == [FolderSample.family.id: 1])
    #expect(self.recorder.events.isEmpty)
  }

  @Test("삭제가 notFound 면 이미 없는 것으로 보고 목록에서 빼고 foldersChanged, dDayDeleted 없음")
  func deleteNotFoundIsSuccess() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)

    let task = try #require(model.deleteConfirmed(id: FolderSample.couple.id, dDays: .delete))
    try await store.waitForPendingDelete()
    try store.resumeDelete(with: .failure(.notFound))
    await task.value

    let remaining = FolderSample.defaults.filter { $0.id != FolderSample.couple.id }
    #expect(model.folders == remaining)
    #expect(model.alert == nil)
    #expect(self.recorder.events == [.foldersChanged(remaining)])
  }

  @Test("deleteConfirmed 를 두 번 불러도 저장소 호출은 한 번")
  func deleteConfirmedTwice() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)

    let task = try #require(model.deleteConfirmed(id: FolderSample.family.id, dDays: .moveToUnfiled))
    #expect(model.deleteConfirmed(id: FolderSample.family.id, dDays: .moveToUnfiled) == nil)
    try await store.waitForPendingDelete()
    try store.resumeDelete(with: .success([]))
    await task.value

    #expect(store.calls.count == 1)
  }

  @Test("확인창 닫힘이 먼저 와도 deleteConfirmed 는 같은 결과, 닫힘은 pendingDeletion 을 남긴다")
  func dismissBeforeConfirm() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    let model = self.recorder.makeManager(store: store)
    model.deleteSwiped(id: FolderSample.other.id)

    model.deleteConfirmationDismissed()
    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.pendingDeletion?.folder == FolderSample.other)

    await model.deleteConfirmed(id: FolderSample.other.id, dDays: .moveToUnfiled)?.value

    let remaining = Array(FolderSample.defaults.dropLast())
    #expect(model.folders == remaining)
    #expect(store.folders == remaining)
  }

  @Test("alertDismissed 는 표시만 끄고 alert 는 남긴다")
  func alertDismissed() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    store.failNextCall(with: .saveFailed)
    let model = self.recorder.makeManager(store: store)
    await model.foldersMoved(fromOffsets: [0], toOffset: 2)?.value
    #expect(model.isAlertPresented)

    model.alertDismissed()

    #expect(!model.isAlertPresented)
    #expect(model.alert == .moveFailed)
  }
}
