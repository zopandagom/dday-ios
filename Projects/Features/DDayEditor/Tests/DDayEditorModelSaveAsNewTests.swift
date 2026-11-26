import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

/// 수정 저장이 `.notFound` 를 받은 뒤: 새로 저장, 취소, 저장 없이 닫기.
@MainActor
struct DDayEditorModelSaveAsNewTests {
  let recorder = OutcomeRecorder()

  /// 원래 디데이가 없는 저장소로 연 수정 모델에서 저장해 `.notFound` 알림창까지 간다.
  func missingOriginalEditor(store: DDayStoreClientFake = DDayStoreClientFake()) async -> DDayEditorModel {
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    await model.saveButtonTapped()?.value
    return model
  }

  @Test("수정 저장이 .notFound 면 새로 저장할지 묻는다")
  func editNotFoundAsksSaveAsNew() async {
    let model = await self.missingOriginalEditor()

    #expect(model.alert == .notFoundOnSave)
    #expect(model.isAlertPresented)
    #expect(model.isOriginalMissing)
    #expect(model.isEditingExisting)
    #expect(model.phase == .editing)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("새로 저장은 새 id 로 추가하고 이후 수정 중이 아니다")
  func saveAsNewAddsNewDDay() async throws {
    let fake = DDayStoreClientFake()
    let model = await self.missingOriginalEditor(store: fake)

    let task = model.saveAsNewTapped()
    #expect(!model.isEditingExisting)
    #expect(!model.isAlertPresented)
    await task?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.id != EditorSample.originalID)
    #expect(saved.title == "엄마 생일")
    #expect(self.recorder.outcomes == [.savedAsNew(saved, replacing: EditorSample.originalID)])
  }

  @Test("알림창 닫힘이 먼저 와도 새로 저장이 같은 차례에 시작한다")
  func saveAsNewWorksWhenAlertDismissedFirst() async throws {
    let fake = DDayStoreClientFake()
    let model = await self.missingOriginalEditor(store: fake)

    model.alertDismissed()
    let task = model.saveAsNewTapped()
    #expect(task != nil)
    #expect(model.phase == .saving)
    await task?.value

    #expect(fake.dDays.count == 1)
    let saved = try #require(fake.dDays.first)
    #expect(self.recorder.outcomes == [.savedAsNew(saved, replacing: EditorSample.originalID)])
  }

  @Test("새로 저장 뒤에 알림창 닫힘이 와도 저장을 이어 간다")
  func saveAsNewWorksWhenAlertDismissedAfter() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    let first = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.notFound))
    await first?.value

    let task = model.saveAsNewTapped()
    model.alertDismissed()
    #expect(model.phase == .saving)
    #expect(model.saveAsNewTapped() == nil)

    try await store.waitForPendingWrite()
    let added = EditorSample.dDay(title: "새 디데이")
    try store.resumeWrite(with: .success(added))
    await task?.value

    #expect(store.calls.count == 2)
    guard case .add = store.calls.last else {
      Issue.record("두 번째 호출이 add 가 아니다")
      return
    }
    #expect(self.recorder.outcomes == [.savedAsNew(added, replacing: EditorSample.originalID)])
  }

  @Test("알림창을 닫아도 알림 종류는 남는다 (닫히는 동안 제목이 바뀌지 않게)")
  func alertKindKeptAfterDismiss() async {
    let model = await self.missingOriginalEditor()

    model.alertDismissed()

    #expect(!model.isAlertPresented)
    #expect(model.alert == .notFoundOnSave)
  }

  @Test("새로 저장이 실패하면 저장 실패 알림창이고, 다음 저장도 추가다")
  func saveAsNewFailureThenSaveUsesAdd() async throws {
    let fake = DDayStoreClientFake()
    let model = await self.missingOriginalEditor(store: fake)
    fake.failNextCall(with: .saveFailed)

    await model.saveAsNewTapped()?.value
    #expect(model.alert == .saveFailed)
    #expect(model.isAlertPresented)
    #expect(model.phase == .editing)
    #expect(!model.isEditingExisting)
    model.alertDismissed()

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.id != EditorSample.originalID)
    #expect(self.recorder.outcomes == [.savedAsNew(saved, replacing: EditorSample.originalID)])
  }

  @Test("일반 수정 저장은 새로 저장이 아니라 saved 다")
  func editSaveStillSaved() async throws {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.titleChanged("바뀐 제목")

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.id == EditorSample.originalID)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("지워진 디데이 알림창에서 [취소]하면 입력이 남고, 다시 저장하면 다시 update 한다")
  func notFoundCancelKeepsEditingAndRetriesUpdate() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.edit(EditorSample.dDay()), store: store, recorder: self.recorder)
    model.titleChanged("바뀐 제목")
    let first = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.notFound))
    await first?.value

    model.alertDismissed()
    #expect(model.title == "바뀐 제목")
    #expect(model.phase == .editing)
    #expect(model.isEditingExisting)

    let second = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.notFound))
    await second?.value

    #expect(store.calls == [
      .update(EditorSample.originalID, model.draft),
      .update(EditorSample.originalID, model.draft),
    ])
    #expect(model.alert == .notFoundOnSave)
    #expect(model.isAlertPresented)
  }

  enum CloseAction: CaseIterable {
    case cancelWithoutChanges, discard, sheetDismissed
  }

  @Test(
    "원래 디데이가 없다고 안 뒤 저장 없이 닫으면 원래 id 를 지워진 것으로 알린다",
    arguments: CloseAction.allCases, [false, true]
  )
  func closeAfterOriginalMissingReportsDeleted(action: CloseAction, afterSaveAsNewFailure: Bool) async {
    let fake = DDayStoreClientFake()
    let model = await self.missingOriginalEditor(store: fake)
    if afterSaveAsNewFailure {
      fake.failNextCall(with: .saveFailed)
      await model.saveAsNewTapped()?.value
      #expect(model.alert == .saveFailed)
    }
    model.alertDismissed()

    switch action {
    case .cancelWithoutChanges:
      #expect(!model.hasChanges)
      model.cancelButtonTapped()
    case .discard:
      model.titleChanged("바뀐 제목")
      model.cancelButtonTapped()
      #expect(model.isDiscardConfirmationPresented)
      model.discardConfirmed()
    case .sheetDismissed:
      model.sheetDismissed()
    }

    #expect(self.recorder.outcomes == [.deleted(EditorSample.originalID)])
    #expect(model.phase == .finished)
  }

  @Test("원래가 없다고 알기 전이나 추가 모드에서는 새로 저장을 무시한다")
  func saveAsNewIgnoredWithoutMissingOriginal() {
    let store = ControlledEditorStore()
    let add = makeEditor(.add, store: store)
    add.titleChanged("제목")
    let edit = makeEditor(.edit(EditorSample.dDay()), store: store)

    #expect(add.saveAsNewTapped() == nil)
    #expect(edit.saveAsNewTapped() == nil)

    #expect(store.calls.isEmpty)
    #expect(add.phase == .editing)
    #expect(edit.phase == .editing)
    #expect(edit.isEditingExisting)
  }
}
