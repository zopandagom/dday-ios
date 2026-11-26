import Core
import DDayEditorFeature
import DDayStoreInterface
import Foundation
import HomeFeature
import Observation

/// 화면 흐름(홈 ↔ 편집 시트) 상태. App 이 `@State` 로 소유한다.
///
/// - 홈의 추가 버튼은 추가 모드, 카드 탭은 수정 모드로 편집 시트를 연다.
/// - 시트를 열고 닫는 판단(떠 있는 동안 다시 열지 않기, 늦게 끝난 옛 편집이 새로 연 시트를 닫지 않기)은
///   Feature 의 순수 값 `DDayEditorPresentation` 이 하고, 여기서는 그 반환값대로 `editor` 를 바꾸기만 한다.
///   불변식: `editor?.id` 와 `presentation.sessionID` 는 늘 같다 (둘을 바꾸는 곳은 열기·끝남·끌어내림 세 곳뿐).
/// - 홈과 편집 화면은 같은 저장소를 쓴다. 편집 결과는 `HomeModel.dDaySaved(_:)`·`dDaySavedAsNew(_:replacing:)`·
///   `dDayDeleted(id:)` 로 1:1 넘기고 홈은 저장소를 다시 읽지 않는다.
/// - 편집 화면은 열 때 "오늘"을 한 번 받아 추가 모드의 시작 날짜로 쓴다.
@MainActor
@Observable
final class AppFlow {
  /// 떠 있는 편집 시트 하나. id 는 `DDayEditorPresentation` 이 돌려준 세션 id 다.
  struct EditorSession: Identifiable {
    let id: UUID
    let model: DDayEditorModel
  }

  let homeModel: HomeModel
  private(set) var editor: EditorSession?

  @ObservationIgnored private var presentation = DDayEditorPresentation()
  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay

  init(store: any DDayStoreClient, today: @escaping @MainActor () -> CalendarDay) {
    // 홈 콜백이 self 를 강하게 잡지 않도록 약한 참조 상자를 넘기고 init 끝에서 채운다.
    let flowReference = WeakAppFlowReference()
    self.store = store
    self.today = today
    self.homeModel = HomeModel(
      store: store,
      today: today,
      onAddTapped: { flowReference.flow?.openEditor(.add) },
      onDDaySelected: { flowReference.flow?.openEditor(.edit($0)) }
    )
    flowReference.flow = self
  }

  /// 시트 바인딩의 set(nil): 끌어내려 닫힘. 떠 있던 세션이면 먼저 editor 를 nil 로 두고 그 모델에 `sheetDismissed()` 를 알린다.
  /// 이미 닫혔으면(프로그램으로 nil 로 바꾼 뒤 다시 불림) `dismissed()` 가 nil 이라 아무것도 하지 않는다.
  func editorSheetDismissed() {
    guard let dismissedID = self.presentation.dismissed(), let session = self.editor else { return }
    assert(session.id == dismissedID, "editor 와 presentation 의 세션이 어긋났다")
    self.editor = nil
    session.model.sheetDismissed()
  }

  // MARK: - Private

  private func openEditor(_ mode: DDayEditorMode) {
    guard let sessionID = self.presentation.open(newID: UUID()) else { return }
    let model = DDayEditorModel(
      mode: mode,
      store: self.store,
      today: self.today(),
      onFinished: { [weak self] outcome in
        self?.editorFinished(outcome, sessionID: sessionID)
      }
    )
    self.editor = EditorSession(id: sessionID, model: model)
  }

  /// 떠 있는 세션의 결과면 시트를 내리고, 끌어내려 닫은 뒤 늦게 끝난 옛 세션이면 결과만 넘긴다.
  private func editorFinished(_ outcome: DDayEditorOutcome, sessionID: UUID) {
    if self.presentation.finished(sessionID: sessionID) {
      self.editor = nil
    }
    switch outcome {
    case let .saved(dDay):
      self.homeModel.dDaySaved(dDay)
    case let .savedAsNew(dDay, replacing: originalID):
      self.homeModel.dDaySavedAsNew(dDay, replacing: originalID)
    case let .deleted(id):
      // 삭제, 또는 원래 디데이가 저장소에 없다고 안 뒤 저장 없이 닫음.
      self.homeModel.dDayDeleted(id: id)
    case .cancelled:
      break
    }
  }
}

/// `AppFlow` 를 약하게 가리키는 상자. 홈 콜백이 init 중에 만들어지므로 self 대신 이것을 잡는다.
@MainActor
private final class WeakAppFlowReference {
  weak var flow: AppFlow?
}
