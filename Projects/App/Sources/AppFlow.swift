import Core
import DDayEditorFeature
import DDayStoreInterface
import FolderManagerFeature
import Foundation
import HomeFeature
import LocalNotificationInterface
import Observation
import PhotoInterface
import ReminderFeature

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
/// - 폴더 관리: 홈의 [폴더 관리](칩·툴바)가 관리 시트(NavigationStack 안쪽, 홈 위)를 열고, 그 안에서 추가·수정 폼을 push 한다.
///   관리 시트와 편집 시트는 동시에 뜨지 않는다 (관리 시트가 떠 있으면 편집을 열지 않고, 편집 시트가 떠 있으면 관리를 열지 않는다).
///   이전 관리·폼 작업이 저장소에서 끝나기 전에는 관리 시트를 다시 열지 않는다. 열고 닫는 판단은 Feature 의 순수 값
///   `FolderManagerPresentation` 이 하고, 여기서는 반환값대로 `folderManager`·`folderForm` 을 바꾸기만 한다.
///   불변식: `folderManager?.id == folderPresentation.sessionID`, `folderForm?.id == folderPresentation.formSessionID`
///   (바꾸는 곳은 열기·폼 열기·폼 끝남·폼 닫힘·시트 닫힘뿐).
///   관리 모델은 홈의 폴더 목록·디데이 수로 시작하고 저장소에서 폴더를 읽지 않는다. 폼 결과는 관리 모델(`formFinished`)로,
///   관리 결과는 홈·상세에 `foldersChanged(_:)`·`dDayDeleted(id:)` 로 넘긴다. 시트·폼이 닫힌 뒤 끝난 작업의 결과도
///   세션으로 거르지 않고 그대로 넘긴다 (결과는 저장소에 이미 반영됐다). 상세가 지금 보는 디데이가 함께 지워지면 상세를 닫는다.
/// - 알림: 다시 예약하는 `reminderModel`(Feature `Reminder`, 화면 없음)을 여기서 만들어 소유한다. 앱 시작·복귀는 App 루트가,
///   디데이 변경은 여기서 알린다: 편집 결과(saved·savedAsNew·deleted, 끌어내려 닫은 뒤 늦게 끝난 옛 편집 포함), 폴더와 함께 지운
///   디데이, 홈 스와이프 삭제 성공(`.notFound` 포함). 홈·상세 반영과 시트 내림 뒤에 부르고 결과는 기다리지 않는다.
///   권한은 알림 날짜가 하나 이상 켜진 디데이(`reminder.scheduledDaysBefore` 가 비어 있지 않음)를 저장한 결과에서만 요청하고
///   (시트를 내린 같은 차례, 상태가 미결정일 때만 `reminderModel` 이 프롬프트를 띄운다), 앱 시작·복귀·삭제에서는 요청하지 않는다.
///   편집 화면에는 열 때 권한 거부 여부(`reminderModel.authorization == .denied`)를 넘기고, 열린 동안 권한이 바뀌면
///   (`onAuthorizationChanged`) 떠 있는 편집 모델에 다시 넘긴다. 편집 화면의 [설정 열기] 는
///   `reminderModel.notificationSettingsRequested()` 로 잇는다 (설정 화면은 Client 가 연다).
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

  /// 떠 있는 폴더 관리 시트 하나. id 는 `FolderManagerPresentation` 이 돌려준 세션 id 다.
  struct FolderManagerSession: Identifiable {
    let id: UUID
    let model: FolderManagerModel
  }

  /// 관리 시트 안에 push 된 폴더 폼 하나. `==`·`hash` 는 세션 id 만 본다 (DetailSession 과 같다).
  struct FolderFormSession: Identifiable, Hashable {
    let id: UUID
    let model: FolderFormModel

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(self.id)
    }
  }

  let homeModel: HomeModel
  /// 알림 권한·다시 예약. App 루트가 앱 시작·복귀를 알린다.
  let reminderModel: ReminderModel
  private(set) var detail: DetailSession?
  private(set) var editor: EditorSession?
  private(set) var folderManager: FolderManagerSession?
  private(set) var folderForm: FolderFormSession?

  @ObservationIgnored private var presentation = DDayEditorPresentation()
  @ObservationIgnored private var folderPresentation = FolderManagerPresentation()
  /// 마지막으로 만든 관리·폼 모델. 세션을 닫아도 지우지 않고 새로 열 때 덮는다 (이전 작업이 끝났는지 보려고).
  @ObservationIgnored private var lastFolderManagerModel: FolderManagerModel?
  @ObservationIgnored private var lastFolderFormModel: FolderFormModel?
  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let photoClient: any PhotoClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay

  init(
    store: any DDayStoreClient,
    photoClient: any PhotoClient,
    notifications: any LocalNotificationClient,
    today: @escaping @MainActor () -> CalendarDay
  ) {
    // 홈·알림 콜백이 self 를 강하게 잡지 않도록 약한 참조 상자를 넘기고 init 끝에서 채운다.
    let flowReference = WeakAppFlowReference()
    self.store = store
    self.photoClient = photoClient
    self.today = today
    self.homeModel = HomeModel(
      store: store,
      today: today,
      onAddTapped: { folderID in flowReference.flow?.openEditor(.add, defaultFolderID: folderID) },
      onDDaySelected: { flowReference.flow?.openDetail($0) },
      onFolderManagerTapped: { flowReference.flow?.openFolderManager() },
      onDDayDeleted: { _ in flowReference.flow?.rescheduleReminders(requestAuthorizationIfNeeded: false) }
    )
    self.reminderModel = ReminderModel(
      store: store,
      notifications: notifications,
      now: { Date() },
      timeZone: { .autoupdatingCurrent },
      onAuthorizationChanged: { flowReference.flow?.notificationAuthorizationChanged($0) }
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

  /// 관리 시트 바인딩의 set(nil): 닫힘 ([닫기]·끌어내림). 시트와 폼을 내린다. 저장소 작업·콜백은 끝까지 돈다.
  /// 이미 닫혔으면 아무것도 하지 않는다.
  func folderManagerDismissed() {
    guard self.folderPresentation.dismissed() != nil else { return }
    self.folderManager = nil
    self.folderForm = nil
  }

  /// 폼 바인딩의 set(nil): 뒤로 가기. 저장 중이 아니면 입력은 버린다. 이미 닫혔으면 아무것도 하지 않는다.
  func folderFormDismissed() {
    guard self.folderPresentation.formDismissed() != nil else { return }
    self.folderForm = nil
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
    // 관리 시트가 떠 있으면 편집을 열지 않는다 (두 시트는 동시에 뜨지 않는다).
    guard !self.folderPresentation.isPresented else { return }
    guard let sessionID = self.presentation.open(newID: UUID()) else { return }
    let model = DDayEditorModel(
      mode: mode,
      store: self.store,
      photoClient: self.photoClient,
      today: self.today(),
      folders: self.homeModel.folders,
      defaultFolderID: defaultFolderID,
      isNotificationDenied: self.reminderModel.authorization == .denied,
      onNotificationSettingsTapped: { [weak self] in
        guard let reminderModel = self?.reminderModel else { return }
        Task { await reminderModel.notificationSettingsRequested() }
      },
      onFinished: { [weak self] outcome in
        self?.editorFinished(outcome, sessionID: sessionID)
      }
    )
    self.editor = EditorSession(id: sessionID, model: model)
  }

  /// 떠 있는 세션의 결과면 시트를 내리고, 끌어내려 닫은 뒤 늦게 끝난 옛 세션이면 결과만 넘긴다.
  /// 결과는 홈과 (떠 있으면) 상세 둘 다에 넘기고, 상세가 지금 보는 디데이가 지워졌으면 상세를 닫는다.
  /// 그 뒤 알림을 다시 예약한다 (알림 날짜가 켜진 디데이를 저장했으면 권한 요청과 함께, 취소면 하지 않는다).
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
    // 시트를 내린 같은 차례에 부르므로 권한 프롬프트는 시트 위가 아니라 내려가는 중·뒤의 화면 위에 뜬다.
    switch outcome {
    case let .saved(dDay), let .savedAsNew(dDay, replacing: _):
      self.rescheduleReminders(requestAuthorizationIfNeeded: !dDay.reminder.scheduledDaysBefore.isEmpty)
    case .deleted:
      self.rescheduleReminders(requestAuthorizationIfNeeded: false)
    case .cancelled:
      break
    }
  }

  /// 디데이가 바뀜: 알림을 다시 예약한다. 결과는 기다리지 않는다 (겹친 요청은 `reminderModel` 이 한 번 더로 모은다).
  private func rescheduleReminders(requestAuthorizationIfNeeded: Bool) {
    let reminderModel = self.reminderModel
    Task { await reminderModel.dDaysChanged(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded) }
  }

  /// 읽은 알림 권한이 바뀜 (`reminderModel` 의 `onAuthorizationChanged`): 떠 있는 편집 모델에 거부 여부를 넘긴다.
  /// 편집이 떠 있지 않으면 아무것도 하지 않는다 (다음에 열 때 `reminderModel.authorization` 을 읽는다).
  /// 끌어내려 닫는 중인 모델은 `phase == .finished` 라 무시한다.
  private func notificationAuthorizationChanged(_ status: NotificationAuthorization) {
    self.editor?.model.notificationAuthorizationChanged(isDenied: status == .denied)
  }
}

extension AppFlow {
  /// 홈의 [폴더 관리]: 관리 시트를 연다. 떠 있거나, 편집 시트가 떠 있거나, 이전 관리·폼 작업이 끝나지 않았으면 무시한다.
  private func openFolderManager() {
    let isPreviousWorkInFlight = self.lastFolderManagerModel?.isBusy == true
      || self.lastFolderFormModel?.phase == .saving
    guard let sessionID = self.folderPresentation.open(
      newID: UUID(),
      isEditorPresented: self.editor != nil,
      isPreviousWorkInFlight: isPreviousWorkInFlight
    ) else { return }
    // 관리 모델의 폼 열기 콜백이 모델 자신을 넘기도록 약한 상자를 쓰고 만든 뒤 채운다 (순환 참조 없음).
    let managerReference = WeakFolderManagerReference()
    let model = FolderManagerModel(
      folders: self.homeModel.folders,
      dDayCounts: self.homeModel.folderDDayCounts,
      store: self.store,
      onAddTapped: { [weak self] in
        guard let manager = managerReference.model else { return }
        self?.openFolderForm(.add, managerSessionID: sessionID, manager: manager)
      },
      onEditTapped: { [weak self] folder in
        guard let manager = managerReference.model else { return }
        self?.openFolderForm(.edit(folder), managerSessionID: sessionID, manager: manager)
      },
      onFoldersChanged: { [weak self] folders in
        self?.homeModel.foldersChanged(folders)
        self?.detail?.model.foldersChanged(folders)
      },
      onDDayDeleted: { [weak self] id in
        self?.folderDDayDeleted(id: id)
      }
    )
    managerReference.model = model
    self.lastFolderManagerModel = model
    self.folderManager = FolderManagerSession(id: sessionID, model: model)
  }

  /// 관리 화면의 [새 폴더]·행 탭: 폼을 push 한다. 그 관리 세션이 떠 있고 폼이 없을 때만 연다.
  /// 폼 결과 클로저는 관리 모델을 강하게 잡는다 (관리 세션이 닫힌 뒤 와도 관리 모델 → 홈으로 넘긴다).
  private func openFolderForm(_ mode: FolderFormMode, managerSessionID: UUID, manager: FolderManagerModel) {
    guard let formSessionID = self.folderPresentation.openForm(newID: UUID(), managerSessionID: managerSessionID)
    else { return }
    let model = FolderFormModel(mode: mode, store: self.store) { [weak self] outcome in
      self?.folderFormFinished(outcome, formSessionID: formSessionID, manager: manager)
    }
    self.lastFolderFormModel = model
    self.folderForm = FolderFormSession(id: formSessionID, model: model)
  }

  /// 떠 있는 폼이면 pop 하고, 결과는 늘 관리 모델에 넘긴다 (관리 모델이 홈·상세에 넘긴다).
  private func folderFormFinished(_ outcome: FolderFormOutcome, formSessionID: UUID, manager: FolderManagerModel) {
    if self.folderPresentation.formFinished(formSessionID: formSessionID) {
      self.folderForm = nil
    }
    manager.formFinished(outcome)
  }

  /// 폴더와 함께 지운 디데이: 홈·상세에 넘기고, 상세가 지금 보는 디데이면 상세를 닫은 뒤 알림을 다시 예약한다
  /// (함께 지운 수만큼 불려도 `reminderModel` 이 겹친 요청을 모아 최대 두 회차).
  private func folderDDayDeleted(id: UUID) {
    self.homeModel.dDayDeleted(id: id)
    self.detail?.model.dDayDeleted(id: id)
    if self.detail?.model.isRemoved == true {
      self.detail = nil
    }
    self.rescheduleReminders(requestAuthorizationIfNeeded: false)
  }
}

/// 관리 모델을 약하게 가리키는 상자. 관리 모델의 콜백이 만들어질 때 모델이 아직 없으므로 이것을 잡는다.
@MainActor
private final class WeakFolderManagerReference {
  weak var model: FolderManagerModel?
}

/// `AppFlow` 를 약하게 가리키는 상자. 홈 콜백이 init 중에 만들어지므로 self 대신 이것을 잡는다.
@MainActor
private final class WeakAppFlowReference {
  weak var flow: AppFlow?
}
