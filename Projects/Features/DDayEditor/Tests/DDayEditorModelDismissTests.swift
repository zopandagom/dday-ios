import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

@MainActor
struct DDayEditorModelDismissTests {
  let recorder = OutcomeRecorder()

  @Test("변경이 없으면 취소로 바로 닫힌다")
  func cancelWithoutChangesFinishesCancelled() {
    let (model, _) = makeEditEditor(recorder: self.recorder)

    model.cancelButtonTapped()

    #expect(!model.isDiscardConfirmationPresented)
    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.phase == .finished)
  }

  @Test("변경이 있으면 취소는 버리기 확인창을 띄운다")
  func cancelWithChangesAsksDiscard() {
    let model = makeEditor(.add, recorder: self.recorder)
    model.titleChanged("제목")

    model.cancelButtonTapped()

    #expect(model.isDiscardConfirmationPresented)
    #expect(model.phase == .editing)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("변경 내용 버리기를 고르면 취소로 닫힌다")
  func discardConfirmedFinishesCancelled() {
    let model = makeEditor(.add, recorder: self.recorder)
    model.titleChanged("제목")
    model.cancelButtonTapped()

    model.discardConfirmed()

    #expect(!model.isDiscardConfirmationPresented)
    #expect(self.recorder.outcomes == [.cancelled])
  }

  @Test("계속 편집을 고르면 입력이 그대로다")
  func discardConfirmationDismissedKeepsEditing() {
    let model = makeEditor(.add, recorder: self.recorder)
    model.titleChanged("제목")
    model.cancelButtonTapped()

    model.discardConfirmationDismissed()

    #expect(!model.isDiscardConfirmationPresented)
    #expect(model.title == "제목")
    #expect(model.phase == .editing)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("확인창 닫힘이 먼저 와도 뒤에 와도 버리기는 한 번 닫는다", arguments: [true, false])
  func discardConfirmedWorksWhenDialogDismissedFirst(dismissFirst: Bool) {
    let model = makeEditor(.add, recorder: self.recorder)
    model.titleChanged("제목")
    model.cancelButtonTapped()

    if dismissFirst {
      model.discardConfirmationDismissed()
    }
    model.discardConfirmed()
    if !dismissFirst {
      model.discardConfirmationDismissed()
    }

    #expect(self.recorder.outcomes == [.cancelled])
  }

  @Test("변경이 있거나 저장 중이면 끌어내려 닫기를 막는다")
  func dismissDisabledWhenChangedOrBusy() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    #expect(!model.isDismissDisabled)

    model.titleChanged("바뀐 제목")
    #expect(model.isDismissDisabled)
    model.titleChanged("엄마 생일")
    #expect(!model.isDismissDisabled)

    let task = model.saveButtonTapped()
    #expect(model.isDismissDisabled)
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value
    #expect(!model.isDismissDisabled)
  }

  @Test("편집 중 시트가 내려가면 취소로 끝난다")
  func sheetDismissedWhileEditingCancels() {
    let model = makeEditor(.add, recorder: self.recorder)

    model.sheetDismissed()

    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.phase == .finished)
  }

  @Test("저장 중 시트가 내려가면 무시하고 저장 결과를 한 번 보낸다")
  func sheetDismissedWhileSavingWaitsForResult() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.add, store: store, recorder: self.recorder)
    model.titleChanged("제목")

    let task = model.saveButtonTapped()
    model.sheetDismissed()
    #expect(self.recorder.outcomes.isEmpty)
    #expect(model.phase == .saving)

    try await store.waitForPendingWrite()
    let saved = EditorSample.dDay(title: "제목")
    try store.resumeWrite(with: .success(saved))
    await task?.value

    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("저장 실패·삭제 실패 알림창을 닫으면 숨기기만 하고 입력·단계는 그대로다", arguments: [true, false])
  func alertDismissedHidesAlert(isSave: Bool) async {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.titleChanged("바뀐 제목")
    fake.failNextCall(with: .saveFailed)
    if isSave {
      await model.saveButtonTapped()?.value
    } else {
      await model.deleteConfirmed()?.value
    }
    #expect(model.isAlertPresented)

    model.alertDismissed()

    #expect(!model.isAlertPresented)
    #expect(model.alert == (isSave ? .saveFailed : .deleteFailed))
    #expect(model.title == "바뀐 제목")
    #expect(model.phase == .editing)
    #expect(self.recorder.outcomes.isEmpty)
  }
}
