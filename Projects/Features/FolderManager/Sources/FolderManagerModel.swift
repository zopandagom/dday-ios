import Core
import DDayStoreInterface
import Foundation
import Observation

/// 폴더 관리 목록의 상태와 로직. App(또는 Example)이 만들어 소유한다.
///
/// - 폴더 목록·디데이 수는 저장소에서 읽지 않고 App 이 열 때 넘긴 홈의 값(`HomeModel.folders`·`folderDDayCounts`)으로 시작한다.
/// - 추가·수정 폼은 이 모델이 모른다: [새 폴더]·행 탭은 콜백(`onAddTapped`·`onEditTapped`)으로 App 에 알리고,
///   폼 결과는 App 이 `formFinished(_:)` 로 넘긴다.
/// - 순서 바꾸기·삭제는 같은 차례에 목록을 바꾸고(새 순서·숨김) 저장소에 쓴다. 성공하면 `onFoldersChanged` 로 새 목록을,
///   함께 지운 디데이는 `onDDayDeleted` 로 하나씩 알린다. 실패하면 목록을 작업 전으로 되돌리고 알림을 띄운다
///   (저장소는 실패한 호출의 변경을 남기지 않으므로 화면과 저장소가 같다).
/// - 저장소 호출은 한 번에 하나(`phase`)다. 바쁜 동안 온 이동·밀기·추가·행 탭은 무시한다.
/// - 취소는 없다: 시트가 닫혀도 Task 는 끝까지 돌고 콜백을 그대로 부른다 (App 이 홈에 넘긴다).
@MainActor
@Observable
public final class FolderManagerModel {
  public enum Phase: Equatable, Sendable {
    case idle
    /// 순서 저장 중 (목록은 이미 새 순서)
    case moving
    /// 그 폴더 삭제 중 (목록에서 이미 숨김)
    case deleting(UUID)
  }

  public enum Alert: Equatable, Sendable {
    case moveFailed
    case deleteFailed
  }

  /// 삭제 확인창에 보일 것. 닫혀도 남겨 닫히는 동안 버튼이 바뀌지 않게 한다 (새 밀기가 덮는다).
  public struct PendingDeletion: Equatable, Sendable {
    public let folder: DDayFolder
    /// 안의 디데이 수 (열 때 받은 값). 0 이면 확인창은 [삭제]·[취소] 만.
    public let dDayCount: Int

    public init(folder: DDayFolder, dDayCount: Int) {
      self.folder = folder
      self.dDayCount = dDayCount
    }
  }

  public private(set) var folders: [DDayFolder]
  /// 폴더 id → 안의 디데이 수 (App 이 열 때 넘긴 홈 값. 지운 폴더 키는 뺀다, 새 폴더는 0)
  public private(set) var dDayCounts: [UUID: Int]
  public private(set) var phase: Phase = .idle
  public private(set) var pendingDeletion: PendingDeletion?
  public private(set) var isDeleteConfirmationPresented = false
  public private(set) var alert: Alert?
  public private(set) var isAlertPresented = false

  /// 저장소 작업 중 (이동·삭제). View 는 이때 끌기·밀기·[닫기]·[새 폴더] 를 막는다.
  public var isBusy: Bool {
    self.phase != .idle
  }

  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let onAddTapped: @MainActor () -> Void
  @ObservationIgnored private let onEditTapped: @MainActor (DDayFolder) -> Void
  @ObservationIgnored private let onFoldersChanged: @MainActor ([DDayFolder]) -> Void
  @ObservationIgnored private let onDDayDeleted: @MainActor (UUID) -> Void

  /// - Parameters:
  ///   - folders: 처음 폴더 목록 (홈이 불러온 순서).
  ///   - dDayCounts: 폴더 id → 안의 디데이 수. 없는 키는 0 으로 본다.
  ///   - onAddTapped: [새 폴더]. App 이 추가 폼을 연다.
  ///   - onEditTapped: 행 탭. App 이 그 폴더의 수정 폼을 연다.
  ///   - onFoldersChanged: 저장에 성공한 작업마다 바뀐 전체 목록.
  ///   - onDDayDeleted: 폴더와 함께 지운 디데이 id (하나씩, 저장소가 돌려준 순서).
  public init(
    folders: [DDayFolder],
    dDayCounts: [UUID: Int],
    store: any DDayStoreClient,
    onAddTapped: @escaping @MainActor () -> Void,
    onEditTapped: @escaping @MainActor (DDayFolder) -> Void,
    onFoldersChanged: @escaping @MainActor ([DDayFolder]) -> Void,
    onDDayDeleted: @escaping @MainActor (UUID) -> Void
  ) {
    self.folders = folders
    self.dDayCounts = dDayCounts
    self.store = store
    self.onAddTapped = onAddTapped
    self.onEditTapped = onEditTapped
    self.onFoldersChanged = onFoldersChanged
    self.onDDayDeleted = onDDayDeleted
  }

  // MARK: - Events

  /// [새 폴더]. 바쁘면 무시한다.
  public func addButtonTapped() {
    guard !self.isBusy else { return }
    self.onAddTapped()
  }

  /// 행 탭: 그 폴더의 수정 폼을 연다. 바쁘거나 목록에 없는 id 면 무시한다.
  public func folderTapped(id: UUID) {
    guard !self.isBusy, let folder = self.folders.first(where: { $0.id == id }) else { return }
    self.onEditTapped(folder)
  }

  /// 끌어서 순서 바꾸기 (`onMove` 의 값). 같은 차례에 새 순서로 바꾸고 저장 Task 를 돌려준다.
  /// 바쁘거나 순서가 그대로면 무시하고 nil (저장소를 부르지 않는다).
  @discardableResult
  public func foldersMoved(fromOffsets offsets: IndexSet, toOffset destination: Int) -> Task<Void, Never>? {
    guard !self.isBusy else { return nil }
    let previous = self.folders
    let orderedIDs = Self.moved(previous.map(\.id), fromOffsets: offsets, toOffset: destination)
    guard orderedIDs != previous.map(\.id) else { return nil }
    let folderByID = Dictionary(previous.map { ($0.id, $0) }) { first, _ in first }
    self.folders = orderedIDs.compactMap { folderByID[$0] }
    self.phase = .moving
    return Task { await self.finishMove(orderedIDs, previous: previous) }
  }

  /// 밀어서 삭제: 확인창을 띄운다. 바쁘거나 목록에 없는 id 면 무시한다.
  public func deleteSwiped(id: UUID) {
    guard !self.isBusy, let folder = self.folders.first(where: { $0.id == id }) else { return }
    self.pendingDeletion = PendingDeletion(folder: folder, dDayCount: self.dDayCounts[id] ?? 0)
    self.isDeleteConfirmationPresented = true
  }

  /// 확인창의 삭제 버튼. 같은 차례에 확인창을 닫고 그 폴더를 목록에서 숨긴 뒤 저장소 삭제 Task 를 돌려준다.
  /// 확인창 표시 상태·`pendingDeletion` 은 보지 않는다 (닫힘 이벤트와 순서가 어떻든 같은 결과).
  /// 바쁘거나 목록에 없는 id 면 무시하고 nil.
  @discardableResult
  public func deleteConfirmed(id: UUID, dDays: FolderDeletion) -> Task<Void, Never>? {
    guard !self.isBusy, let index = self.folders.firstIndex(where: { $0.id == id }) else { return nil }
    self.isDeleteConfirmationPresented = false
    let previous = self.folders
    self.folders.remove(at: index)
    self.phase = .deleting(id)
    return Task { await self.finishDelete(id: id, dDays: dDays, previous: previous) }
  }

  /// 확인창이 닫힘 (취소·바깥 탭). `pendingDeletion` 은 남긴다.
  public func deleteConfirmationDismissed() {
    self.isDeleteConfirmationPresented = false
  }

  /// 실패 알림이 닫힘. `alert` 는 남긴다 (닫히는 동안 제목이 바뀌지 않게).
  public func alertDismissed() {
    self.isAlertPresented = false
  }

  /// 폼이 저장함 (App 이 넘긴다). phase 는 보지 않는다 (폼이 떠 있는 동안 목록 작업은 없다).
  /// 추가는 같은 id 가 없을 때만 끝에 넣고 디데이 수 0, 수정은 같은 id 자리를 바꾼다 (없는 id 면 무시).
  public func formFinished(_ outcome: FolderFormOutcome) {
    switch outcome {
    case let .added(folder):
      guard !self.folders.contains(where: { $0.id == folder.id }) else { return }
      self.folders.append(folder)
      self.dDayCounts[folder.id] = 0
    case let .updated(folder):
      guard let index = self.folders.firstIndex(where: { $0.id == folder.id }) else { return }
      self.folders[index] = folder
    }
    self.onFoldersChanged(self.folders)
  }

  // MARK: - 순서 계산

  /// `MutableCollection.move(fromOffsets:toOffset:)` 와 같은 뜻 (SwiftUI 없이): 옮길 원소를 원래 순서대로 꺼내고,
  /// 남은 배열에서 "옮기기 전 배열의 `toOffset` 앞" 자리에 넣는다. 범위 밖 offset 은 무시(clamp), 빈 IndexSet 은 그대로.
  static func moved(_ ids: [UUID], fromOffsets offsets: IndexSet, toOffset destination: Int) -> [UUID] {
    let valid = offsets.filter { ids.indices.contains($0) }
    guard !valid.isEmpty else { return ids }
    let movingSet = Set(valid)
    let moving = valid.sorted().map { ids[$0] }
    let remaining = ids.indices.filter { !movingSet.contains($0) }.map { ids[$0] }
    let before = valid.count { $0 < destination }
    let insertion = min(max(destination - before, 0), remaining.count)
    var result = remaining
    result.insert(contentsOf: moving, at: insertion)
    return result
  }

  // MARK: - Private

  private func finishMove(_ orderedIDs: [UUID], previous: [DDayFolder]) async {
    do {
      let folders = try await self.store.moveFolders(orderedIDs)
      self.folders = folders
      self.phase = .idle
      self.onFoldersChanged(folders)
    } catch {
      // `.notFound`(오래된 목록) 도 같다: 되돌리고 알린다. 시트를 다시 열면 홈의 최신 목록으로 회복한다.
      self.folders = previous
      self.phase = .idle
      self.showAlert(.moveFailed)
    }
  }

  private func finishDelete(id: UUID, dDays: FolderDeletion, previous: [DDayFolder]) async {
    do {
      let deletedIDs = try await self.store.deleteFolder(id: id, dDays: dDays)
      for dDayID in deletedIDs {
        self.onDDayDeleted(dDayID)
      }
      self.finishDeleteSuccess(id: id)
    } catch .notFound {
      // 이미 없는 것은 원하는 결과다. 함께 지운 디데이는 알 수 없어 알리지 않는다.
      self.finishDeleteSuccess(id: id)
    } catch {
      self.folders = previous
      self.phase = .idle
      self.showAlert(.deleteFailed)
    }
  }

  private func finishDeleteSuccess(id: UUID) {
    self.dDayCounts[id] = nil
    self.phase = .idle
    self.onFoldersChanged(self.folders)
  }

  private func showAlert(_ alert: Alert) {
    self.alert = alert
    self.isAlertPresented = true
  }
}
