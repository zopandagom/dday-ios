import Core
import DDayEditorFeature
import DDayStoreInterface
import Foundation
import HomeFeature
import Observation
import PhotoInterface

/// 화면 흐름(홈 → 상세 push → 편집 시트) 상태. App 이 `@State` 로 소유한다.
///
/// - 홈의 추가 버튼은 추가 모드 편집 시트를, 카드 탭은 그 디데이의 상세 화면(NavigationStack push)을 연다.
///   상세의 [편집] 은 수정 모드 편집 시트를 연다. 시트는 NavigationStack 바깥이라 상세 위에서도 전체를 덮는다.
/// - 상세는 `detail` 하나만 둔다. 떠 있는 동안 카드 탭이 또 와도(두 번 탭, push 중 탭) 다시 열지 않는다.
///   닫힘은 `navigationDestination(item:)` 바인딩의 set(nil)(뒤로 가기·가장자리 스와이프)이 `detailDismissed()` 로 알린다.
///   세션 id 는 디데이 id 가 아니라 새 UUID 다: savedAsNew 로 디데이 id 가 바뀌어도 같은 세션이라 다시 push 하지 않는다.
/// - 시트를 열고 닫는 판단(떠 있는 동안 다시 열지 않기, 늦게 끝난 옛 편집이 새로 연 시트를 닫지 않기)은
///   Feature 의 순수 값 `DDayEditorPresentation` 이 하고, 여기서는 그 반환값대로 `editor` 를 바꾸기만 한다.
///   불변식: `editor?.id` 와 `presentation.sessionID` 는 늘 같다 (둘을 바꾸는 곳은 열기·끝남·끌어내림 세 곳뿐).
/// - 홈·상세·편집 화면은 같은 저장소를 쓴다. 편집 결과는 `dDaySaved(_:)`·`dDaySavedAsNew(_:replacing:)`·
///   `dDayDeleted(id:)` 로 홈(`HomeModel`)과 상세(`DDayDetailModel`) 둘 다에 1:1 넘기고, 둘 다 목록을 다시 읽지 않는다.
///   상세가 지금 보는 디데이가 지워졌는지는 상세 모델이 판단해 `isRemoved` 로 두고, 여기서는 넘긴 뒤 그 값을 보고 닫는다.
/// - 편집 화면은 열 때 "오늘"을 한 번 받아 추가 모드의 시작 날짜로 쓴다.
/// - 폴더 목록은 홈이 불러온 값(`homeModel.folders`)을 상세·편집을 열 때 넘긴다 (편집 화면은 폴더를 읽지 않는다).
///   추가 모드의 기본 폴더는 홈에서 고른 칩이다 (`onAddTapped` 의 인자).
/// - 편집 화면의 사진 처리(읽기·자르기·JPEG 만들기)는 앱에 하나인 `photoClient` 로 한다.
@MainActor
@Observable
final class AppFlow {
  /// 떠 있는 편집 시트 하나. id 는 `DDayEditorPresentation` 이 돌려준 세션 id 다.
  struct EditorSession: Identifiable {
    let id: UUID
    let model: DDayEditorModel
  }

  /// 떠 있는 상세 화면 하나. `==`·`hash` 는 세션 id 만 본다 (모델이 바뀌어도 같은 push 로 본다).
  struct DetailSession: Identifiable, Hashable {
    let id: UUID
    let model: DDayDetailModel

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }

  let homeModel: HomeModel
  private(set) var detail: DetailSession?
  private(set) var editor: EditorSession?

  @ObservationIgnored private var presentation = DDayEditorPresentation()
  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let photoClient: any PhotoClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay

  init(
    store: any DDayStoreClient,
    photoClient: any PhotoClient,
    today: @escaping @MainActor () -> CalendarDay
  ) {
    // 홈 콜백이 self 를 강하게 잡지 않도록 약한 참조 상자를 넘기고 init 끝에서 채운다.
    let flowReference = WeakAppFlowReference()
    self.store = store
    self.photoClient = photoClient
    self.today = today
    self.homeModel = HomeModel(
      store: store,
      today: today,
      onAddTapped: { folderID in flowReference.flow?.openEditor(.add, defaultFolderID: folderID) },
      onDDaySelected: { flowReference.flow?.openDetail($0) }
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

  /// 상세 바인딩의 set(nil): 뒤로 가기·가장자리 스와이프로 닫힘. 이미 nil 이면(프로그램으로 닫은 뒤 다시 불림) 아무것도 하지 않는다.
  func detailDismissed() {
    guard self.detail != nil else { return }
    self.detail = nil
  }

  // MARK: - Private

  /// 카드 탭: 상세를 연다. 이미 떠 있으면(두 번 탭·push 중 탭) 무시한다.
  private func openDetail(_ dDay: DDay) {
    guard self.detail == nil else { return }
    let model = DDayDetailModel(
      dDay: dDay,
      folders: self.homeModel.folders,
      store: self.store,
      today: self.today,
      onEditTapped: { [weak self] dDay in
        self?.openEditor(.edit(dDay))
      }
    )
    self.detail = DetailSession(id: UUID(), model: model)
  }

  /// - Parameter defaultFolderID: 추가 모드의 처음 폴더 (홈에서 고른 칩). 수정 모드는 쓰지 않는다.
  private func openEditor(_ mode: DDayEditorMode, defaultFolderID: UUID? = nil) {
    guard let sessionID = self.presentation.open(newID: UUID()) else { return }
    let model = DDayEditorModel(
      mode: mode,
      store: self.store,
      photoClient: self.photoClient,
      today: self.today(),
      folders: self.homeModel.folders,
      defaultFolderID: defaultFolderID,
      onFinished: { [weak self] outcome in
        self?.editorFinished(outcome, sessionID: sessionID)
      }
    )
    self.editor = EditorSession(id: sessionID, model: model)
  }

  /// 떠 있는 세션의 결과면 시트를 내리고, 끌어내려 닫은 뒤 늦게 끝난 옛 세션이면 결과만 넘긴다.
  /// 결과는 홈과 (떠 있으면) 상세 둘 다에 넘기고, 상세가 지금 보는 디데이가 지워졌으면 상세를 닫는다.
  private func editorFinished(_ outcome: DDayEditorOutcome, sessionID: UUID) {
    if self.presentation.finished(sessionID: sessionID) {
      self.editor = nil
    }
    switch outcome {
    case let .saved(dDay):
      self.homeModel.dDaySaved(dDay)
      self.detail?.model.dDaySaved(dDay)
    case let .savedAsNew(dDay, replacing: originalID):
      self.homeModel.dDaySavedAsNew(dDay, replacing: originalID)
      self.detail?.model.dDaySavedAsNew(dDay, replacing: originalID)
    case let .deleted(id):
      // 삭제, 또는 원래 디데이가 저장소에 없다고 안 뒤 저장 없이 닫음.
      self.homeModel.dDayDeleted(id: id)
      self.detail?.model.dDayDeleted(id: id)
    case .cancelled:
      break
    }
    // 시트 내림과 같은 차례에 아래 상세도 닫는다.
    if self.detail?.model.isRemoved == true {
      self.detail = nil
    }
  }
}

/// `AppFlow` 를 약하게 가리키는 상자. 홈 콜백이 init 중에 만들어지므로 self 대신 이것을 잡는다.
@MainActor
private final class WeakAppFlowReference {
  weak var flow: AppFlow?
}
