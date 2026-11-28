import Foundation
import Testing
@testable import FolderManagerFeature

struct FolderManagerPresentationTests {
  private let firstSession = UUID()
  private let secondSession = UUID()
  private let firstFormSession = UUID()
  private let secondFormSession = UUID()

  private func opened() -> FolderManagerPresentation {
    var presentation = FolderManagerPresentation()
    _ = presentation.open(newID: self.firstSession, isEditorPresented: false, isPreviousWorkInFlight: false)
    return presentation
  }

  @Test("처음 열기는 그 id 를 돌려주고 떠 있는 동안 다시 열지 않는다")
  func openOnce() {
    var presentation = FolderManagerPresentation()

    let firstOpen = presentation.open(newID: self.firstSession, isEditorPresented: false, isPreviousWorkInFlight: false)
    #expect(firstOpen == self.firstSession)
    #expect(presentation.isPresented)
    let secondOpen = presentation.open(
      newID: self.secondSession,
      isEditorPresented: false,
      isPreviousWorkInFlight: false
    )
    #expect(secondOpen == nil)
    #expect(presentation.sessionID == self.firstSession)
  }

  @Test("편집 시트가 떠 있으면 열지 않는다")
  func editorBlocksOpen() {
    var presentation = FolderManagerPresentation()

    let blockedOpen = presentation.open(
      newID: self.firstSession,
      isEditorPresented: true,
      isPreviousWorkInFlight: false
    )
    #expect(blockedOpen == nil)
    #expect(!presentation.isPresented)
  }

  @Test("이전 작업 중이면 열지 않고, 끝나면 열린다")
  func previousWorkBlocksOpen() {
    var presentation = FolderManagerPresentation()

    let blockedOpen = presentation.open(
      newID: self.firstSession,
      isEditorPresented: false,
      isPreviousWorkInFlight: true
    )
    #expect(blockedOpen == nil)
    let openAfterWork = presentation.open(
      newID: self.secondSession,
      isEditorPresented: false,
      isPreviousWorkInFlight: false
    )
    #expect(openAfterWork == self.secondSession)
  }

  @Test("닫은 뒤 다시 열 수 있다")
  func reopenAfterDismiss() {
    var presentation = self.opened()

    let dismissedID = presentation.dismissed()
    #expect(dismissedID == self.firstSession)
    let reopened = presentation.open(newID: self.secondSession, isEditorPresented: false, isPreviousWorkInFlight: false)
    #expect(reopened == self.secondSession)
  }

  @Test("폼 열기는 id 를 돌려주고, 떠 있으면 두 번째는 nil")
  func openFormOnce() {
    var presentation = self.opened()

    let firstForm = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)
    #expect(firstForm == self.firstFormSession)
    let secondForm = presentation.openForm(newID: self.secondFormSession, managerSessionID: self.firstSession)
    #expect(secondForm == nil)
    #expect(presentation.formSessionID == self.firstFormSession)
  }

  @Test("닫힌(다른) 관리 세션 id 나 시트 없이 폼을 열지 않는다")
  func openFormNeedsCurrentSession() {
    var closed = FolderManagerPresentation()
    let formWithoutSheet = closed.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)
    #expect(formWithoutSheet == nil)

    var presentation = self.opened()
    let formForOtherSession = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.secondSession)
    #expect(formForOtherSession == nil)
    #expect(presentation.formSessionID == nil)
  }

  @Test("formFinished: 떠 있는 폼이면 true 로 닫고, 이미 닫힌 폼이면 false")
  func formFinished() {
    var presentation = self.opened()
    _ = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)

    let finishedOpenForm = presentation.formFinished(formSessionID: self.firstFormSession)
    #expect(finishedOpenForm)
    #expect(presentation.formSessionID == nil)

    _ = presentation.openForm(newID: self.secondFormSession, managerSessionID: self.firstSession)
    let dismissedFormID = presentation.formDismissed()
    #expect(dismissedFormID == self.secondFormSession)
    let finishedClosedForm = presentation.formFinished(formSessionID: self.secondFormSession)
    #expect(!finishedClosedForm)
  }

  @Test("새 폼이 떠 있을 때 옛 폼의 formFinished 는 false 이고 새 폼을 남긴다")
  func staleFormFinishedKeepsNewForm() {
    var presentation = self.opened()
    _ = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)
    _ = presentation.formDismissed()
    _ = presentation.openForm(newID: self.secondFormSession, managerSessionID: self.firstSession)

    let finishedStaleForm = presentation.formFinished(formSessionID: self.firstFormSession)
    #expect(!finishedStaleForm)
    #expect(presentation.formSessionID == self.secondFormSession)
  }

  @Test("formDismissed 는 멱등")
  func formDismissedIdempotent() {
    var presentation = self.opened()
    _ = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)

    let firstDismiss = presentation.formDismissed()
    #expect(firstDismiss == self.firstFormSession)
    let secondDismiss = presentation.formDismissed()
    #expect(secondDismiss == nil)
  }

  @Test("dismissed 는 폼도 닫고 멱등, 닫은 뒤 옛 폼의 formFinished 는 false")
  func dismissedClosesForm() {
    var presentation = self.opened()
    _ = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)

    let firstDismiss = presentation.dismissed()
    #expect(firstDismiss == self.firstSession)
    #expect(presentation.formSessionID == nil)
    let secondDismiss = presentation.dismissed()
    #expect(secondDismiss == nil)
    let finishedAfterDismiss = presentation.formFinished(formSessionID: self.firstFormSession)
    #expect(!finishedAfterDismiss)
  }

  @Test("시트를 닫았다 다시 연 뒤 옛 폼 id 의 formFinished 는 false")
  func staleFormAfterReopen() {
    var presentation = self.opened()
    _ = presentation.openForm(newID: self.firstFormSession, managerSessionID: self.firstSession)
    _ = presentation.dismissed()
    _ = presentation.open(newID: self.secondSession, isEditorPresented: false, isPreviousWorkInFlight: false)

    let finishedStaleForm = presentation.formFinished(formSessionID: self.firstFormSession)
    #expect(!finishedStaleForm)
    #expect(presentation.sessionID == self.secondSession)
  }
}
