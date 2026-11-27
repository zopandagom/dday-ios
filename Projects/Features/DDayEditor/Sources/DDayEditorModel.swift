import Core
import CoreGraphics
import DDayStoreInterface
import Foundation
import Observation
import PhotoInterface

/// 디데이 추가·수정 화면의 상태와 로직.
///
/// - `date` 는 늘 고를 수 있는 값이다 (양력: `KoreanLunarCalendar.supportedSolarRange` 안, 음력: `solarDay(from:)` 가 nil 이 아님).
///   수정 모드에서 저장된 날짜를 고를 수 없으면 가까운 값으로 맞추고 `isDateAdjusted` 로 알린다.
/// - 저장·새로 저장·삭제는 동기 이벤트가 같은 차례에 `phase` 를 바꾸고 저장소 Task 를 돌려준다.
///   `phase != .editing` 이면 입력·저장·삭제·닫기 이벤트는 무시되므로 두 번 눌러도 저장소 호출은 한 번이다.
/// - 알림창·확인창 버튼의 동작 이벤트는 창의 표시 상태를 조건으로 보지 않는다. 닫힘 이벤트(바인딩 set(false))가
///   버튼 동작보다 먼저 오든 나중에 오든 결과가 같다.
/// - `onFinished` 는 모델당 정확히 한 번 부른다. 그 뒤 모든 이벤트는 무시한다.
/// - 사진: 고르기(`photoPicked`) → 불러오기(`.loading`) → 자르기(`.cropping`) → 만들기(`.rendering`) → `.new`.
///   늦게 끝난 사진 처리 결과는 요청 id 가 같고 `phase == .editing` 일 때만 반영한다. 사진 처리 중
///   (`photoStep != .idle`)에는 저장·새로 저장·삭제를 시작하지 않고, [취소]·버리기·시트 닫기는 받는다
///   (닫히면 사진 Task 를 취소하고 늦은 결과는 버린다). 처리 실패·취소면 기존 사진·입력을 그대로 둔다.
@MainActor
@Observable
public final class DDayEditorModel: Identifiable {
  /// 입력 그대로 (정리 전).
  public private(set) var title: String
  /// 늘 고를 수 있는 값.
  public private(set) var date: DDayDate
  public private(set) var repeatRule: RepeatRule
  public private(set) var countingStyle: CountingStyle
  public private(set) var reminderIsEnabled: Bool
  /// 켜진 알림 날짜 (`ReminderSettings.daysBeforeChoices` 안). 화면 순서는 `reminderDayChoices`.
  public private(set) var enabledReminderDays: Set<Int>
  public private(set) var reminderTime: TimeOfDay
  /// D+·1일째 방식에서 100일 단위 기념일에도 알린다. 다른 방식에서도 값은 남긴다.
  public private(set) var remindsEveryHundredDays: Bool
  /// D+·1일째 방식에서 N주년에도 알린다. 같은 규칙.
  public private(set) var remindsAnniversaries: Bool
  public private(set) var phase: Phase = .editing
  /// 마지막으로 띄운 알림 종류. 닫혀도 남겨 닫히는 동안 제목·버튼이 바뀌지 않게 한다. 새 알림이 덮는다.
  public private(set) var alert: Alert?
  public private(set) var isAlertPresented = false
  public private(set) var isDiscardConfirmationPresented = false
  public private(set) var isDeleteConfirmationPresented = false
  /// 수정 모드면 true. "새로 저장"을 고르면 false (이후 저장은 모두 추가, 삭제 버튼 숨김).
  public private(set) var isEditingExisting: Bool
  /// 수정 저장이 `.notFound` 를 받았다 (원래 디데이가 저장소에 없다). 한 번 true 면 그대로.
  public private(set) var isOriginalMissing = false
  /// 저장된 날짜를 고를 수 없어 맞췄다 (안내 문구). 받아들인 날짜 이벤트가 끈다.
  public private(set) var isDateAdjusted = false
  /// 사진 상태. 바꾸는 길은 `EditorPhotoState.apply(_:)` 의 전이뿐이다 (이 파일의 "사진 상태 전이 통로").
  public private(set) var photoState: EditorPhotoState
  /// 수정 저장이 `.notFound` 를 받아 저장된 사진을 잃었다 (원래 디데이와 함께 압축본도 지워졌다). 한 번 true 면 그대로.
  public private(set) var isStoredPhotoLost = false
  /// 폴더 선택 (열 때 받은 목록에서 고른다, 저장소에서 읽지 않는다). 바꾸는 길은 `folderChanged(_:)` 뿐이다.
  public private(set) var folderSelection: EditorFolderSelection

  @ObservationIgnored let mode: DDayEditorMode
  @ObservationIgnored let initialDraft: DDayDraft
  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let onFinished: @MainActor (DDayEditorOutcome) -> Void
  @ObservationIgnored let photoClient: any PhotoClient
  /// 수정 모드의 처음 사진 (`photoChange` 가 지움을 `.remove` 로 보낼지 정한다).
  @ObservationIgnored let originalPhoto: DDayPhoto?
  /// 진행 중인 사진 처리 Task (닫기·불러오기 취소가 취소한다). 요청 id 는 `photoState` 가 갖는다.
  @ObservationIgnored private var photoTask: Task<Void, Never>?

  /// - Parameter today: 추가 모드의 시작 날짜 (양력 지원 범위로 맞춘다). 수정 모드는 쓰지 않는다. 폴더 인자는 `EditorFolderSelection`.
  public init(
    mode: DDayEditorMode,
    store: any DDayStoreClient,
    photoClient: any PhotoClient,
    today: CalendarDay,
    folders: [DDayFolder] = [],
    defaultFolderID: UUID? = nil,
    onFinished: @escaping @MainActor (DDayEditorOutcome) -> Void
  ) {
    self.mode = mode
    self.store = store
    self.photoClient = photoClient
    self.onFinished = onFinished
    let folderSelection = EditorFolderSelection(mode: mode, folders: folders, defaultFolderID: defaultFolderID)
    self.folderSelection = folderSelection
    var initialDraft: DDayDraft
    switch mode {
    case .add:
      let reminder = ReminderSettings.default
      self.title = ""
      let date = DDayDate.solar(Self.clampedSolar(today))
      self.date = date
      self.repeatRule = .none
      self.countingStyle = .dDay
      self.reminderIsEnabled = reminder.isEnabled
      self.enabledReminderDays = reminder.enabledDaysBefore
      self.reminderTime = reminder.time
      self.remindsEveryHundredDays = reminder.remindsEveryHundredDays
      self.remindsAnniversaries = reminder.remindsAnniversaries
      self.isEditingExisting = false
      self.photoState = EditorPhotoState(photo: .none)
      self.originalPhoto = nil
      initialDraft = DDayDraft(title: "", schedule: DDaySchedule(date: date), reminder: reminder)
    case let .edit(dDay):
      let (date, isAdjusted) = Self.selectable(dDay.schedule.date)
      self.title = dDay.title
      self.date = date
      self.repeatRule = dDay.schedule.repeatRule
      self.countingStyle = dDay.schedule.countingStyle
      self.reminderIsEnabled = dDay.reminder.isEnabled
      self.enabledReminderDays = dDay.reminder.enabledDaysBefore
      self.reminderTime = dDay.reminder.time
      self.remindsEveryHundredDays = dDay.reminder.remindsEveryHundredDays
      self.remindsAnniversaries = dDay.reminder.remindsAnniversaries
      self.isEditingExisting = true
      self.isDateAdjusted = isAdjusted
      self.photoState = EditorPhotoState(photo: dDay.photo.map { .stored($0) } ?? .none)
      self.originalPhoto = dDay.photo
      // 제목만 정리하고 날짜는 맞추기 전 저장값: 맞췄으면 hasChanges 가 true 라 말없이 덮지 않는다.
      initialDraft = DDayDraft(title: Self.trimmed(dDay.title), schedule: dDay.schedule, reminder: dDay.reminder)
    }
    initialDraft.folderID = folderSelection.folderID
    self.initialDraft = initialDraft
  }
}

// 상태를 바꾸는 이벤트는 `private(set)` 세터를 쓰므로 이 파일의 extension 에 둔다.
// 음력 선택 이벤트는 `changeLunar` 만 부르므로 `DDayEditorModel+Lunar.swift` 에, 사진 이벤트는 아래 "사진 상태 전이
// 통로"(전이만 받고 편집 중일 때만 적용)만 부르므로 `DDayEditorModel+Photo.swift` 에 둔다. 중첩 타입은 `DDayEditorModel+Types.swift`.

public extension DDayEditorModel {
  // MARK: - 입력 이벤트

  func titleChanged(_ text: String) {
    guard self.phase == .editing else { return }
    self.title = text
  }

  /// 같은 날을 다른 달력으로 바꾼다. 같은 종류면 무시.
  func calendarKindChanged(_ kind: CalendarKind) {
    guard self.phase == .editing, kind != self.calendarKind else { return }
    switch self.date {
    case let .solar(day):
      guard let lunar = KoreanLunarCalendar.lunarDate(from: day)
        ?? KoreanLunarCalendar.lunarDate(from: Self.clampedSolar(day))
      else {
        return
      }
      self.date = .lunar(lunar)
    case let .lunar(lunar):
      guard let day = KoreanLunarCalendar.solarDay(from: lunar) else { return }
      self.date = .solar(day)
    }
    self.isDateAdjusted = false
  }

  /// 양력일 때만. 지원 범위로 맞춘다.
  func solarDayChanged(_ day: CalendarDay) {
    guard self.phase == .editing, case .solar = self.date else { return }
    self.date = .solar(Self.clampedSolar(day))
    self.isDateAdjusted = false
  }

  func repeatRuleChanged(_ rule: RepeatRule) {
    guard self.phase == .editing else { return }
    self.repeatRule = rule
  }

  /// 알림 값(기념일 토글 포함)은 건드리지 않는다. D-day 로 바꾸면 기념일 토글은 숨기기만 한다.
  func countingStyleChanged(_ style: CountingStyle) {
    guard self.phase == .editing else { return }
    self.countingStyle = style
  }

  /// 켜진 알림 날짜는 그대로 둔다.
  func reminderEnabledChanged(_ isEnabled: Bool) {
    guard self.phase == .editing else { return }
    self.reminderIsEnabled = isEnabled
  }

  /// 그 날짜의 켜짐을 바꾼다. 고정 선택지(`ReminderSettings.daysBeforeChoices`) 밖이면 무시.
  func reminderDayEnabledChanged(daysBefore: Int, isEnabled: Bool) {
    guard self.phase == .editing, ReminderSettings.daysBeforeChoices.contains(daysBefore) else { return }
    if isEnabled {
      self.enabledReminderDays.insert(daysBefore)
    } else {
      self.enabledReminderDays.remove(daysBefore)
    }
  }

  func reminderTimeChanged(_ time: TimeOfDay) {
    guard self.phase == .editing else { return }
    self.reminderTime = time
  }

  /// D+·1일째 방식일 때만 (`showsMilestoneReminders`). 알림 켜짐은 보지 않는다 (View 가 숨긴다).
  func everyHundredDaysReminderChanged(_ isOn: Bool) {
    guard self.phase == .editing, self.showsMilestoneReminders else { return }
    self.remindsEveryHundredDays = isOn
  }

  /// D+·1일째 방식일 때만 (`showsMilestoneReminders`). 알림 켜짐은 보지 않는다 (View 가 숨긴다).
  func anniversaryReminderChanged(_ isOn: Bool) {
    guard self.phase == .editing, self.showsMilestoneReminders else { return }
    self.remindsAnniversaries = isOn
  }

  func folderChanged(_ folderID: UUID?) {
    guard self.phase == .editing else { return }
    self.folderSelection.select(folderID)
  }
}

public extension DDayEditorModel {
  // MARK: - 저장

  /// 툴바 [저장]. 같은 차례에 `.saving` 으로 바꾸고 저장 Task 를 돌려준다. 저장할 수 없으면 nil.
  /// 원래가 없다고 알아도([취소]를 고른 뒤) 수정 모드면 다시 update 한다.
  @discardableResult
  func saveButtonTapped() -> Task<Void, Never>? {
    guard self.canSave else { return nil }
    let draft = self.draft
    let updateID: UUID? = if self.isEditingExisting, case let .edit(original) = self.mode {
      original.id
    } else {
      nil
    }
    self.phase = .saving
    return Task { await self.finishSave(draft, updateID: updateID) }
  }

  /// "이미 지워진 디데이" 알림창의 [새로 저장]. 알림창 표시 상태는 보지 않는다.
  @discardableResult
  func saveAsNewTapped() -> Task<Void, Never>? {
    guard self.canSave, self.isEditingExisting, self.isOriginalMissing else { return nil }
    self.isAlertPresented = false
    self.isEditingExisting = false
    let draft = self.draft
    self.phase = .saving
    return Task { await self.finishSave(draft, updateID: nil) }
  }

  // MARK: - 삭제

  /// 수정 중일 때만 삭제 확인창을 띄운다.
  /// 사진 처리 중에는 무시한다 (불러오는 중 삭제가 실패해 돌아오면 `.loading` 에 갇히지 않게).
  func deleteButtonTapped() {
    guard self.phase == .editing, self.photoStep == .idle, self.isEditingExisting else { return }
    self.isDeleteConfirmationPresented = true
  }

  /// 삭제 확인창의 [삭제]. 확인창 표시 상태는 보지 않는다. 같은 차례에 `.deleting` 으로 바꾸고 삭제 Task 를 돌려준다.
  @discardableResult
  func deleteConfirmed() -> Task<Void, Never>? {
    self.isDeleteConfirmationPresented = false
    guard self.phase == .editing, self.photoStep == .idle, self.isEditingExisting,
          case let .edit(original) = self.mode
    else {
      return nil
    }
    self.phase = .deleting
    return Task { await self.finishDelete(id: original.id) }
  }

  func deleteConfirmationDismissed() {
    self.isDeleteConfirmationPresented = false
  }

  // MARK: - 닫기

  /// 툴바 [취소]. 변경이 없으면 닫고, 있으면 버리기 확인창을 띄운다.
  func cancelButtonTapped() {
    guard self.phase == .editing else { return }
    if self.hasChanges {
      self.isDiscardConfirmationPresented = true
    } else {
      self.finish(self.closeOutcome)
    }
  }

  /// 버리기 확인창의 [변경 내용 버리기]. 확인창 표시 상태는 보지 않는다.
  func discardConfirmed() {
    guard self.phase == .editing else { return }
    self.isDiscardConfirmationPresented = false
    self.finish(self.closeOutcome)
  }

  func discardConfirmationDismissed() {
    self.isDiscardConfirmationPresented = false
  }

  /// 표시 여부만 내린다 (`alert` 값은 남긴다).
  func alertDismissed() {
    self.isAlertPresented = false
  }

  /// 시트가 내려감 (App 이 부른다). 편집 중이면 닫는다. 저장·삭제 중이면 무시하고 그 결과를 그대로 보낸다.
  func sheetDismissed() {
    guard self.phase == .editing else { return }
    self.finish(self.closeOutcome)
  }
}

extension DDayEditorModel {
  // MARK: - 사진 상태 전이 통로

  /// 사진 이벤트(`+Photo.swift`)의 통로: 이벤트 전이만 받아 편집 중일 때만 적용하고 받았는지 돌려준다.
  @discardableResult
  func applyPhotoEvent(_ event: EditorPhotoState.EventTransition) -> Bool {
    self.applyPhotoTransition(event.transition)
  }

  /// 시작 전이를 받았으면 `work`(시작 뒤 상태를 받는다)의 결과 전이를 적용하는 Task, 아니면 nil. 결과도 편집 중·같은 요청일 때만.
  func startPhotoWork(
    _ start: EditorPhotoState.StartTransition,
    work: @escaping @MainActor @Sendable (EditorPhotoState) async -> EditorPhotoState.FinishTransition
  ) -> Task<Void, Never>? {
    guard self.applyPhotoTransition(start.transition) else { return nil }
    let state = self.photoState
    let task = Task { _ = await self.applyPhotoTransition(work(state).transition) }
    self.photoTask = task
    return task
  }

  /// 편집 중이면 적용한다. 받은 `.cancelLoad` 는 불러오기 Task 를 취소한다.
  @discardableResult
  private func applyPhotoTransition(_ transition: EditorPhotoState.Transition) -> Bool {
    guard self.phase == .editing, self.photoState.apply(transition) else { return false }
    if case .cancelLoad = transition {
      self.cancelPhotoTask()
    }
    return true
  }

  private func cancelPhotoTask() {
    self.photoTask?.cancel()
    self.photoTask = nil
  }
}

extension DDayEditorModel {
  // MARK: - Private

  /// 음력일 때만 음력 날짜를 바꾼다 (음력 선택 이벤트는 `DDayEditorModel+Lunar.swift`).
  func changeLunar(_ transform: (LunarDate) -> LunarDate) {
    guard self.phase == .editing, case let .lunar(lunar) = self.date else { return }
    self.date = .lunar(transform(lunar))
    self.isDateAdjusted = false
  }

  /// 취소된 Task 여도 결과를 반영한다 (저장소는 취소를 보지 않는다).
  private func finishSave(_ draft: DDayDraft, updateID: UUID?) async {
    do throws(DDayStoreError) {
      let saved = if let updateID {
        try await self.store.update(id: updateID, draft)
      } else {
        try await self.store.add(draft)
      }
      // 수정 모드의 add 는 "새로 저장"을 고른 뒤에만 일어난다.
      if updateID == nil, case let .edit(original) = self.mode {
        self.finish(.savedAsNew(saved, replacing: original.id))
      } else {
        self.finish(.saved(saved))
      }
    } catch {
      self.phase = .editing
      if error == .notFound, updateID != nil {
        self.isOriginalMissing = true
        // 원래 디데이와 함께 압축본도 지워졌다. 미리보기와 "새로 저장" 결과를 맞춘다 (새로 고른 사진은 그대로).
        if self.photoState.apply(.dropStoredPhoto) {
          self.isStoredPhotoLost = true
        }
        self.alert = .notFoundOnSave
      } else {
        self.alert = .saveFailed
      }
      self.isAlertPresented = true
    }
  }

  private func finishDelete(id: UUID) async {
    do throws(DDayStoreError) {
      try await self.store.delete(id: id)
      self.finish(.deleted(id))
    } catch .notFound {
      // 이미 없는 것은 원하는 결과다 (홈 스와이프 삭제와 같은 규칙).
      self.finish(.deleted(id))
    } catch {
      self.phase = .editing
      self.alert = .deleteFailed
      self.isAlertPresented = true
    }
  }

  /// 닫히면 진행 중인 사진 처리를 취소한다 (늦은 결과는 `phase == .finished` 라 버린다).
  private func finish(_ outcome: DDayEditorOutcome) {
    guard self.phase != .finished else { return }
    self.phase = .finished
    self.photoState.apply(.endRequest)
    self.cancelPhotoTask()
    self.onFinished(outcome)
  }
}
