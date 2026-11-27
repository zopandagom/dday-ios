import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

/// 폴더 선택: 열 때 받은 목록, 추가 모드 기본 폴더, 수정 모드 저장된 폴더, 저장 draft.
@MainActor
struct DDayEditorModelFolderTests {
  let recorder = OutcomeRecorder()

  func adding(defaultFolderID: UUID?, store: any DDayStoreClient = DDayStoreClientFake()) -> DDayEditorModel {
    makeEditor(
      .add,
      store: store,
      folders: EditorSample.folders,
      defaultFolderID: defaultFolderID,
      recorder: self.recorder
    )
  }

  func editing(folderID: UUID?, store: (any DDayStoreClient)? = nil) -> DDayEditorModel {
    let dDay = EditorSample.dDay(folderID: folderID)
    return makeEditor(
      .edit(dDay),
      store: store ?? DDayStoreClientFake(dDays: [dDay], folders: EditorSample.folders),
      folders: EditorSample.folders,
      recorder: self.recorder
    )
  }

  // MARK: init (추가)

  @Test("추가: 목록에 있는 기본 폴더(칩)로 열고 변경 없음으로 본다")
  func addDefaultFolderInList() {
    let model = self.adding(defaultFolderID: EditorSample.family.id)

    #expect(model.folders == EditorSample.folders)
    #expect(model.folderID == EditorSample.family.id)
    #expect(!model.hasChanges)
    #expect(!model.isDismissDisabled)
  }

  @Test("추가: 목록에 없는 기본 폴더면 미분류이고 변경 없음")
  func addDefaultFolderMissing() {
    let model = self.adding(defaultFolderID: EditorSample.missingFolderID)

    #expect(model.folderID == nil)
    #expect(!model.hasChanges)
  }

  @Test("추가: 기본 폴더가 nil 이면 미분류")
  func addNoDefaultFolder() {
    let model = self.adding(defaultFolderID: nil)

    #expect(model.folderID == nil)
    #expect(!model.hasChanges)
  }

  @Test("추가: 폴더 목록이 비면(홈 불러오기 전) 기본 폴더가 있어도 미분류")
  func addWithoutFolderList() {
    let model = makeEditor(.add, defaultFolderID: EditorSample.family.id)

    #expect(model.folders.isEmpty)
    #expect(model.folderID == nil)
    #expect(!model.hasChanges)
  }

  // MARK: init (수정)

  @Test("수정: 저장된 폴더로 연다")
  func editStoredFolder() {
    let model = self.editing(folderID: EditorSample.couple.id)

    #expect(model.folderID == EditorSample.couple.id)
    #expect(!model.hasChanges)
  }

  @Test("수정: 저장된 폴더가 목록에 없으면 미분류로 열고 변경 없음으로 본다")
  func editStoredFolderMissing() {
    let model = self.editing(folderID: EditorSample.missingFolderID)

    #expect(model.folderID == nil)
    #expect(!model.hasChanges)
    #expect(!model.isDismissDisabled)
  }

  @Test("수정 모드는 기본 폴더 인자를 쓰지 않는다")
  func editIgnoresDefaultFolder() {
    let dDay = EditorSample.dDay(folderID: nil)
    let model = makeEditor(
      .edit(dDay),
      folders: EditorSample.folders,
      defaultFolderID: EditorSample.family.id
    )

    #expect(model.folderID == nil)
  }

  // MARK: folderChanged

  @Test("목록에 있는 폴더와 미분류를 받고, 바꾸면 변경 있음")
  func folderChangedApplies() {
    let model = self.adding(defaultFolderID: nil)

    model.folderChanged(EditorSample.couple.id)
    #expect(model.folderID == EditorSample.couple.id)
    #expect(model.hasChanges)
    #expect(model.isDismissDisabled)

    model.folderChanged(nil)
    #expect(model.folderID == nil)
    #expect(!model.hasChanges)
  }

  @Test("목록에 없는 폴더는 무시한다")
  func folderChangedUnknownIgnored() {
    let model = self.adding(defaultFolderID: EditorSample.family.id)

    model.folderChanged(EditorSample.missingFolderID)

    #expect(model.folderID == EditorSample.family.id)
    #expect(!model.hasChanges)
  }

  @Test("수정: 다른 폴더로 바꾸면 변경 있음")
  func editFolderChangedHasChanges() {
    let model = self.editing(folderID: EditorSample.couple.id)

    model.folderChanged(EditorSample.family.id)

    #expect(model.hasChanges)
    #expect(model.isDismissDisabled)
  }

  @Test("저장 중에는 폴더 선택을 무시한다")
  func folderChangedIgnoredWhileSaving() async throws {
    let store = ControlledEditorStore()
    let model = self.adding(defaultFolderID: nil, store: store)
    model.titleChanged("여행")
    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()

    model.folderChanged(EditorSample.family.id)

    #expect(model.folderID == nil)
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value
  }

  @Test("끝난 뒤에는 폴더 선택을 무시한다")
  func folderChangedIgnoredAfterFinish() {
    let model = self.adding(defaultFolderID: nil)
    model.cancelButtonTapped()
    #expect(model.phase == .finished)

    model.folderChanged(EditorSample.family.id)

    #expect(model.folderID == nil)
  }

  // MARK: 저장

  @Test("추가 저장 draft 에 고른 폴더가 들어간다")
  func addSaveDraftHasFolder() async throws {
    let store = ControlledEditorStore()
    let model = self.adding(defaultFolderID: EditorSample.family.id, store: store)
    model.titleChanged("할머니 생신")
    model.folderChanged(EditorSample.couple.id)

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    guard case let .add(draft) = store.calls.first else {
      Issue.record("add 가 아니다: \(store.calls)")
      return
    }
    #expect(draft.folderID == EditorSample.couple.id)
  }

  @Test("수정 저장 draft 에 고른 폴더가 들어간다 (미분류로 바꾸면 nil)")
  func updateSaveDraftHasFolder() async throws {
    let store = ControlledEditorStore()
    let model = self.editing(folderID: EditorSample.couple.id, store: store)
    model.folderChanged(nil)

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    #expect(store.calls == [.update(EditorSample.originalID, EditorSample.dDay(folderID: nil).draft)])
  }

  @Test("추가 저장 결과는 저장소가 돌려준 폴더 그대로 알린다")
  func addSaveOutcomeHasFolder() async throws {
    let fake = DDayStoreClientFake(folders: EditorSample.folders)
    let model = self.adding(defaultFolderID: EditorSample.family.id, store: fake)
    model.titleChanged("가족 여행")

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.folderID == EditorSample.family.id)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("폴더를 바꾼 뒤 저장이 실패하면 고른 폴더가 남는다")
  func saveFailureKeepsFolder() async {
    let fake = DDayStoreClientFake(
      dDays: [EditorSample.dDay(folderID: EditorSample.couple.id)],
      folders: EditorSample.folders
    )
    fake.failNextCall(with: .saveFailed)
    let model = self.editing(folderID: EditorSample.couple.id, store: fake)
    model.folderChanged(EditorSample.family.id)

    await model.saveButtonTapped()?.value

    #expect(model.alert == .saveFailed)
    #expect(model.phase == .editing)
    #expect(model.folderID == EditorSample.family.id)
    #expect(model.hasChanges)
    #expect(fake.dDays.first?.folderID == EditorSample.couple.id)
  }

  @Test("새로 저장도 고른 폴더로 추가한다")
  func saveAsNewHasFolder() async throws {
    // 원래 디데이가 없는 저장소: 수정 저장이 .notFound → 새로 저장.
    let fake = DDayStoreClientFake(folders: EditorSample.folders)
    let model = self.editing(folderID: EditorSample.couple.id, store: fake)
    model.folderChanged(EditorSample.family.id)
    await model.saveButtonTapped()?.value
    #expect(model.alert == .notFoundOnSave)

    await model.saveAsNewTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.folderID == EditorSample.family.id)
    #expect(self.recorder.outcomes == [.savedAsNew(saved, replacing: EditorSample.originalID)])
  }
}
