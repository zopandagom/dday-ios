import Foundation
import Testing
@testable import DDayEditorFeature

/// 편집 시트를 띄우고 닫는 판단 (순수 값, 저장소 없음).
struct DDayEditorPresentationTests {
  static let first = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
  static let second = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
  static let third = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!

  @Test("닫혀 있으면 새 id 로 연다")
  func openWhenClosedReturnsNewID() {
    var presentation = DDayEditorPresentation()

    #expect(presentation.sessionID == nil)
    let opened = presentation.open(newID: Self.first)
    #expect(opened == Self.first)
    #expect(presentation.sessionID == Self.first)
  }

  @Test("떠 있는 동안에는 다시 열지 않는다")
  func openWhilePresentedReturnsNil() {
    var presentation = DDayEditorPresentation()
    _ = presentation.open(newID: Self.first)

    let reopened = presentation.open(newID: Self.second)
    #expect(reopened == nil)
    #expect(presentation.sessionID == Self.first)
  }

  @Test("떠 있는 세션이 끝나면 시트를 내린다")
  func finishedCurrentSessionCloses() {
    var presentation = DDayEditorPresentation()
    _ = presentation.open(newID: Self.first)

    let closed = presentation.finished(sessionID: Self.first)
    #expect(closed)
    #expect(presentation.sessionID == nil)
  }

  @Test("끌어내리면 떠 있던 id 를 한 번만 돌려준다")
  func dismissedReturnsPresentedIDOnce() {
    var presentation = DDayEditorPresentation()
    _ = presentation.open(newID: Self.first)

    let dismissedID = presentation.dismissed()
    #expect(dismissedID == Self.first)
    #expect(presentation.sessionID == nil)
    let dismissedAgain = presentation.dismissed()
    #expect(dismissedAgain == nil)
  }

  @Test("늦게 끝난 옛 세션은 새로 연 시트를 닫지 않는다")
  func lateFinishOfOldSessionKeepsNewSession() {
    var presentation = DDayEditorPresentation()
    _ = presentation.open(newID: Self.first)
    _ = presentation.dismissed()
    _ = presentation.open(newID: Self.second)

    let oldClosed = presentation.finished(sessionID: Self.first)
    #expect(!oldClosed)
    #expect(presentation.sessionID == Self.second)
    let newClosed = presentation.finished(sessionID: Self.second)
    #expect(newClosed)
    #expect(presentation.sessionID == nil)
  }

  @Test("끌어내린 뒤 끝난 세션은 false 이고, 그 뒤 다시 열 수 있다")
  func finishedAfterDismissIsFalse() {
    var presentation = DDayEditorPresentation()
    _ = presentation.open(newID: Self.first)
    _ = presentation.dismissed()

    let closedAfterDismiss = presentation.finished(sessionID: Self.first)
    #expect(!closedAfterDismiss)
    let reopenedNew = presentation.open(newID: Self.third)
    #expect(reopenedNew == Self.third)
    #expect(presentation.sessionID == Self.third)
  }

  @Test("닫혀 있을 때 모르는 세션이 끝나도 상태는 그대로다")
  func finishedUnknownIDWhenClosedIsFalse() {
    var presentation = DDayEditorPresentation()

    let finishedUnknown = presentation.finished(sessionID: Self.first)
    #expect(!finishedUnknown)
    #expect(presentation == DDayEditorPresentation())
  }
}
