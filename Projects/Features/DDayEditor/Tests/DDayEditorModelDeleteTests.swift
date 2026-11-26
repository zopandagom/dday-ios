import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

@MainActor
struct DDayEditorModelDeleteTests {
  let recorder = OutcomeRecorder()

  @Test("추가 모드에서는 삭제 버튼과 삭제 확인을 무시한다")
  func deleteButtonIgnoredInAddMode() {
    let store = ControlledEditorStore()
    let model = makeEditor(.add, store: store, recorder: self.recorder)

    model.deleteButtonTapped()
    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.deleteConfirmed() == nil)

    #expect(store.calls.isEmpty)
    #expect(model.phase == .editing)
  }

  @Test("삭제 버튼은 확인창을 띄운다")
  func deleteButtonShowsConfirmation() {
    let (model, _) = makeEditEditor()

    model.deleteButtonTapped()

    #expect(model.isDeleteConfirmationPresented)
  }

  @Test("삭제 확인창을 닫으면 편집을 이어 간다")
  func deleteConfirmationDismissed() {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.deleteButtonTapped()

    model.deleteConfirmationDismissed()

    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.phase == .editing)
    #expect(fake.dDays.count == 1)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("삭제에 성공하면 지운 id 로 끝난다")
  func deleteSuccessFinishesWithDeleted() async {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.deleteButtonTapped()

    await model.deleteConfirmed()?.value

    #expect(fake.dDays.isEmpty)
    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
    #expect(model.phase == .finished)
    #expect(!model.isDeleteConfirmationPresented)
  }

  @Test("삭제 확인은 같은 차례에 삭제 중이 되고, 두 번째 호출은 무시한다")
  func deleteSetsDeletingSynchronously() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    model.deleteButtonTapped()

    let task = model.deleteConfirmed()
    #expect(task != nil)
    #expect(model.phase == .deleting)
    #expect(model.deleteConfirmed() == nil)

    try await store.waitForPendingDelete()
    try store.resumeDelete(with: .success(()))
    await task?.value

    #expect(store.calls == [.delete(EditorSample.originalID)])
    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
  }

  @Test("확인창 닫힘이 먼저 와도 뒤에 와도 삭제는 한 번 시작한다", arguments: [true, false])
  func deleteConfirmedWorksWhenDialogDismissedFirst(dismissFirst: Bool) async {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.deleteButtonTapped()

    if dismissFirst {
      model.deleteConfirmationDismissed()
    }
    let task = model.deleteConfirmed()
    #expect(task != nil)
    #expect(model.phase == .deleting)
    if !dismissFirst {
      model.deleteConfirmationDismissed()
      #expect(model.phase == .deleting)
    }
    await task?.value

    #expect(fake.dDays.isEmpty)
    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
  }

  @Test("삭제가 .notFound 면 지워진 것으로 보고 끝난다")
  func deleteNotFoundTreatedAsDeleted() async {
    let model = makeEditor(.edit(EditorSample.dDay()), store: DDayStoreClientFake(), recorder: self.recorder)
    model.deleteButtonTapped()

    await model.deleteConfirmed()?.value

    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
    #expect(model.phase == .finished)
    #expect(!model.isAlertPresented)
  }

  @Test("삭제 실패면 화면과 입력을 그대로 두고 알림창을 띄운다", arguments: [DDayStoreError.saveFailed, .loadFailed])
  func deleteFailureKeepsScreen(error: DDayStoreError) async {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.titleChanged("바뀐 제목")
    fake.failNextCall(with: error)
    model.deleteButtonTapped()

    await model.deleteConfirmed()?.value

    #expect(model.alert == .deleteFailed)
    #expect(model.isAlertPresented)
    #expect(model.phase == .editing)
    #expect(model.title == "바뀐 제목")
    #expect(model.isEditingExisting)
    #expect(fake.dDays.count == 1)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("삭제 중에는 저장·취소·입력·다시 삭제를 모두 무시한다")
  func whileDeletingEverythingIsIgnored() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    let draft = model.draft

    let task = model.deleteConfirmed()
    #expect(model.isBusy)
    #expect(model.isDismissDisabled)
    #expect(!model.canSave)

    #expect(model.deleteConfirmed() == nil)
    #expect(model.saveButtonTapped() == nil)
    #expect(model.saveAsNewTapped() == nil)
    model.deleteButtonTapped()
    model.cancelButtonTapped()
    model.discardConfirmed()
    model.sheetDismissed()
    model.titleChanged("바뀐 제목")
    model.countingStyleChanged(.dPlus)
    model.reminderDayEnabledChanged(daysBefore: 0, isEnabled: false)
    model.reminderDayEnabledChanged(daysBefore: 7, isEnabled: true)
    model.reminderTimeChanged(EditorSample.time(1, 0))

    #expect(model.draft == draft)
    #expect(model.enabledReminderDays == [0, 30])
    #expect(!model.isDeleteConfirmationPresented)
    #expect(!model.isDiscardConfirmationPresented)
    #expect(model.phase == .deleting)

    try await store.waitForPendingDelete()
    try store.resumeDelete(with: .success(()))
    await task?.value

    #expect(store.calls == [.delete(EditorSample.originalID)])
    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
  }

  @Test("새로 저장을 고른 뒤에는 삭제 버튼을 무시한다")
  func deleteHiddenAfterSaveAsNew() async {
    let fake = DDayStoreClientFake()
    let model = makeEditor(.edit(EditorSample.dDay()), store: fake, recorder: self.recorder)
    // 원래가 없는 저장소에서 update → .notFound, 이어서 새로 저장이 실패해 편집으로 돌아온다.
    await model.saveButtonTapped()?.value
    #expect(model.alert == .notFoundOnSave)
    fake.failNextCall(with: .saveFailed)
    await model.saveAsNewTapped()?.value
    #expect(!model.isEditingExisting)

    model.deleteButtonTapped()

    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.deleteConfirmed() == nil)
    #expect(self.recorder.outcomes.isEmpty)
  }
}
