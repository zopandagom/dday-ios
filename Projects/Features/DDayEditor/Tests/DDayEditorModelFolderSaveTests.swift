import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

/// 폴더 선택의 저장 draft 와 수정 모드에서 건드리지 않은 폴더 보존. `adding`·`editing` 은 DDayEditorModelFolderTests.swift.
extension DDayEditorModelFolderTests {
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

  // MARK: 건드리지 않은 폴더 보존 (수정 모드)

  @Test("수정: 폴더가 목록에 없고 건드리지 않으면 원래 id 를 보내고 변경 없음")
  func untouchedMissingFolderKeepsOriginalID() async throws {
    let store = ControlledEditorStore()
    let model = self.editing(folderID: EditorSample.missingFolderID, store: store)
    #expect(model.folderID == nil)
    #expect(!model.hasChanges)

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    #expect(store.calls == [
      .update(EditorSample.originalID, EditorSample.dDay(folderID: EditorSample.missingFolderID).draft),
    ])
  }

  @Test("수정: 폴더가 목록에 없을 때 미분류를 고르면 nil 을 보내고 변경 있음")
  func touchedUnfiledSendsNil() async throws {
    let store = ControlledEditorStore()
    let model = self.editing(folderID: EditorSample.missingFolderID, store: store)

    model.folderChanged(nil)
    #expect(model.folderSelection.isTouched)
    #expect(model.hasChanges)

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    #expect(store.calls == [.update(EditorSample.originalID, EditorSample.dDay(folderID: nil).draft)])
  }

  @Test("수정: 폴더가 목록에 없을 때 다른 폴더를 고르면 그 id 를 보낸다")
  func touchedOtherFolderSendsIt() async throws {
    let store = ControlledEditorStore()
    let model = self.editing(folderID: EditorSample.missingFolderID, store: store)

    model.folderChanged(EditorSample.family.id)

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    #expect(store.calls == [.update(
      EditorSample.originalID,
      EditorSample.dDay(folderID: EditorSample.family.id).draft
    )])
  }

  @Test("수정: 저장소에는 있고 편집 목록에만 없는 폴더는 건드리지 않고 저장하면 그 폴더로 남는다")
  func untouchedFolderInStoreIsKept() async throws {
    let hidden = DDayFolder(id: EditorSample.missingFolderID, name: .custom("여행"), color: .mint, icon: .airplane)
    let dDay = EditorSample.dDay(folderID: hidden.id)
    let fake = DDayStoreClientFake(dDays: [dDay], folders: EditorSample.folders + [hidden])
    let model = self.editing(folderID: hidden.id, store: fake)
    model.titleChanged("바뀐 제목")

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(saved.folderID == hidden.id)
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("추가 모드는 건드리지 않아도 보이는 폴더(목록에 없으면 미분류)를 보낸다")
  func addModeUnaffected() async throws {
    let store = ControlledEditorStore()
    let model = self.adding(defaultFolderID: EditorSample.missingFolderID, store: store)
    model.titleChanged("여행")

    let task = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await task?.value

    guard case let .add(draft) = store.calls.first else {
      Issue.record("add 가 아니다: \(store.calls)")
      return
    }
    #expect(draft.folderID == nil)
  }

  @Test("새로 저장도 같은 규칙: 건드리지 않았으면 원래 id")
  func saveAsNewKeepsUntouchedOriginalID() async throws {
    let store = ControlledEditorStore()
    let model = self.editing(folderID: EditorSample.missingFolderID, store: store)
    let save = model.saveButtonTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.notFound))
    await save?.value
    #expect(model.alert == .notFoundOnSave)

    let saveAsNew = model.saveAsNewTapped()
    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .failure(.saveFailed))
    await saveAsNew?.value

    guard case let .add(draft) = store.calls.last else {
      Issue.record("add 가 아니다: \(store.calls)")
      return
    }
    #expect(draft.folderID == EditorSample.missingFolderID)
  }
}
