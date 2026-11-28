import Core
import DDayStoreInterface
import DesignSystem
import Foundation
import Observation

/// 폴더 폼의 모드.
public enum FolderFormMode: Hashable, Sendable {
  case add
  case edit(DDayFolder)
}

/// 폴더 폼의 결과 (저장에 성공했을 때만).
public enum FolderFormOutcome: Hashable, Sendable {
  case added(DDayFolder)
  case updated(DDayFolder)
}

/// 폴더 추가·수정 폼의 상태와 로직. App(또는 Example)이 관리 모델의 콜백을 받아 만들고 소유한다.
///
/// - 이름 규칙은 Core `FolderNameRule` 하나로 저장 버튼·안내와 저장소 검증이 같다.
/// - 수정 모드의 기본 폴더(`.system(k)`)는 기본 이름(앱 언어)을 입력칸에 채워 연다. 저장할 때 정리한 이름이 그 기본 이름과
///   같으면 `.system(k)` 를 보내 기본 이름을 유지한다 (언어를 바꾸면 따라 바뀐다). 다르면 `.custom(입력)` 이다.
/// - 저장은 한 번에 하나다 (`phase`). 성공하면 `.finished` 가 되고 `onFinished` 를 정확히 한 번 부른 뒤 모든 이벤트를 무시한다.
///   실패하면 입력을 그대로 두고 `.editing` 으로 돌아와 알림을 띄운다 (다시 저장하거나 뒤로 가서 버린다).
/// - 취소는 없다: 저장 중 화면이 빠져도 Task 는 끝까지 돌고 `onFinished` 를 부른다 (App 이 관리 모델에 넘긴다).
@MainActor
@Observable
public final class FolderFormModel: Identifiable {
  public enum Phase: Equatable, Sendable {
    case editing
    case saving
    case finished
  }

  @ObservationIgnored public let mode: FolderFormMode
  /// 이름 입력 그대로 (정리 전). 수정 모드 기본 이름이면 열 때 앱 언어의 기본 이름 문자열.
  public private(set) var nameText: String
  public private(set) var color: FolderColor
  public private(set) var icon: FolderIcon
  public private(set) var phase: Phase = .editing
  public private(set) var isSaveFailedAlertPresented = false

  /// `FolderNameRule.validate(nameText)`. 폼 footer 와 저장 버튼이 쓴다.
  public var nameValidation: FolderNameRule.Validation {
    FolderNameRule.validate(self.nameText)
  }

  /// 정리한 이름의 글자 수 ("n/20").
  public var nameLength: Int {
    FolderNameRule.length(self.nameText)
  }

  /// 입력 중이고 이름이 규칙에 맞을 때만 저장할 수 있다.
  public var canSave: Bool {
    guard self.phase == .editing, case .valid = self.nameValidation else { return false }
    return true
  }

  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let systemName: @MainActor (DefaultFolder) -> String
  @ObservationIgnored private let onFinished: @MainActor (FolderFormOutcome) -> Void

  /// - Parameter systemName: 기본 폴더 이름의 앱 언어 문자열. 기본값은 DesignSystem `FolderText.defaultName` 을
  ///   `String(localized:)` 한 값 (`FolderFormModel.localizedSystemName`). 테스트는 고정 값을 넘긴다.
  public init(
    mode: FolderFormMode,
    store: any DDayStoreClient,
    systemName: @escaping @MainActor (DefaultFolder) -> String = FolderFormModel.localizedSystemName,
    onFinished: @escaping @MainActor (FolderFormOutcome) -> Void
  ) {
    self.mode = mode
    self.store = store
    self.systemName = systemName
    self.onFinished = onFinished
    switch mode {
    case .add:
      self.nameText = ""
      self.color = .blushPink
      self.icon = .star
    case let .edit(folder):
      switch folder.name {
      case let .system(key): self.nameText = systemName(key)
      case let .custom(name): self.nameText = name
      }
      self.color = folder.color
      self.icon = folder.icon
    }
  }

  /// 기본 폴더 이름을 앱 언어로 (`FolderText.defaultName`).
  public static func localizedSystemName(_ folder: DefaultFolder) -> String {
    String(localized: FolderText.defaultName(folder))
  }

  // MARK: - Events

  public func nameChanged(_ text: String) {
    guard self.phase == .editing else { return }
    self.nameText = text
  }

  public func colorSelected(_ color: FolderColor) {
    guard self.phase == .editing else { return }
    self.color = color
  }

  public func iconSelected(_ icon: FolderIcon) {
    guard self.phase == .editing else { return }
    self.icon = icon
  }

  /// [저장]. 저장할 수 있을 때만 같은 차례에 `.saving` 으로 바꾸고 저장 Task 를 돌려준다. 아니면 nil (두 번 탭 포함).
  @discardableResult
  public func saveButtonTapped() -> Task<Void, Never>? {
    guard self.canSave else { return nil }
    self.phase = .saving
    let draft = DDayFolderDraft(name: self.draftName, color: self.color, icon: self.icon)
    return Task { await self.save(draft) }
  }

  public func saveFailedAlertDismissed() {
    self.isSaveFailedAlertPresented = false
  }

  // MARK: - Private

  /// 수정 모드의 기본 폴더이고 정리한 입력이 기본 이름과 같으면 `.system`, 아니면 `.custom(입력)` (정리는 저장소가 한다).
  private var draftName: FolderName {
    if case let .edit(folder) = self.mode, case let .system(key) = folder.name,
       FolderNameRule.normalized(self.nameText) == self.systemName(key)
    {
      return .system(key)
    }
    return .custom(self.nameText)
  }

  private func save(_ draft: DDayFolderDraft) async {
    let outcome: FolderFormOutcome
    do {
      switch self.mode {
      case .add:
        outcome = try await .added(self.store.addFolder(draft))
      case let .edit(folder):
        outcome = try await .updated(self.store.updateFolder(id: folder.id, draft))
      }
    } catch {
      self.phase = .editing
      self.isSaveFailedAlertPresented = true
      return
    }
    self.phase = .finished
    self.onFinished(outcome)
  }
}
