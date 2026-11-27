import Core
import DDayStoreInterface
import Foundation
import Observation

/// 홈 목록의 상태와 로직. 저장소에서 디데이를 한 번 불러와 오늘 기준으로 정렬해 보여 주고, 스와이프로 지우고, 편집 결과를 반영한다.
///
/// - 불러오기는 한 번뿐이다. 실패하면 다시 시도 버튼·앱 복귀(`sceneBecameActive()`)·편집 저장(`dDaySaved(_:)`)으로 다시 불러온다.
///   한 번 `.loaded` 가 되면 이 모델의 수명 동안 `.loaded` 에서 벗어나지 않으므로 불러오기와 삭제는 겹치지 않는다.
/// - 편집 결과는 `dDaySaved`·`dDaySavedAsNew`·`dDayDeleted` 로 다시 읽지 않고 반영한다. 불러오는 중에 온 결과는 불러오기 결과 위에 적용한다.
///   불러오기 실패 중 저장 결과가 오면 다시 불러온다.
/// - "오늘"은 주입한 `today` 로 구하고, 앱 복귀·날짜 변경·시간대 변경 때 다시 구해 바뀌었을 때만 다시 정렬한다.
///   저장소는 다시 읽지 않는다.
/// - 삭제는 항목을 바로 숨긴 뒤 저장소에서 지운다. 실패하면 원래 자리로 돌려놓고 알림창을 띄운다.
@MainActor
@Observable
public final class HomeModel {
  public enum Content: Equatable {
    /// 처음 불러오는 중, 또는 다시 시도 중
    case loading
    /// 불러오기 실패(저장소 열기 실패 포함)
    case loadFailed
    /// 정렬된 목록. 빈 배열이면 빈 화면.
    case loaded([HomeItem])
  }

  public private(set) var content: Content = .loading
  public private(set) var isDeleteFailedAlertPresented = false

  /// fetchAll 순서(생성 시각 순). 정렬 입력.
  private var dDays: [DDay] = []
  /// 삭제 진행 중이라 숨긴 id.
  private var deletingIDs: Set<UUID> = []
  /// 불러오는 중에 온 편집 결과 (온 순서). 불러오기가 성공하면 그 결과에 적용하고, 끝나면(성공·실패) 비운다.
  private var pendingEdits: [PendingEdit] = []
  /// 마지막 정렬에 쓴 오늘.
  private var currentDay: CalendarDay?
  private var isLoading = false

  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay
  @ObservationIgnored private let onAddTapped: @MainActor () -> Void
  /// 카드 탭. App 이 상세를 연다.
  @ObservationIgnored private let onDDaySelected: @MainActor (DDay) -> Void

  public init(
    store: any DDayStoreClient,
    today: @escaping @MainActor () -> CalendarDay,
    onAddTapped: @escaping @MainActor () -> Void,
    onDDaySelected: @escaping @MainActor (DDay) -> Void
  ) {
    self.store = store
    self.today = today
    self.onAddTapped = onAddTapped
    self.onDDaySelected = onDDaySelected
  }

  // MARK: - Events

  /// 처음 나타날 때 불러온다. 불러오는 중이거나 이미 끝났으면(성공·실패) 아무것도 하지 않는다.
  public func onAppear() async {
    guard self.content == .loading, !self.isLoading else { return }
    await self.load()
  }

  /// 불러오기 실패 화면의 다시 시도.
  public func retryButtonTapped() async {
    await self.retryLoad()
  }

  /// 앱이 다시 활성화됨: 오늘을 다시 구하고, 불러오기에 실패한 상태면 한 번 다시 불러온다.
  public func sceneBecameActive() async {
    self.refreshToday()
    await self.retryLoad()
  }

  /// 날짜·시간대가 바뀜: 오늘을 다시 구한다 (다시 불러오지 않는다).
  public func calendarDayChanged() {
    self.refreshToday()
  }

  public func addButtonTapped() {
    self.onAddTapped()
  }

  /// 카드 탭: App 이 상세를 연다 (`onDDaySelected`). 보이는 항목만 선택한다 (삭제 중이거나 없는 id 는 무시).
  public func dDayTapped(id: UUID) {
    guard !self.deletingIDs.contains(id), let dDay = self.dDays.first(where: { $0.id == id }) else { return }
    self.onDDaySelected(dDay)
  }

  /// 스와이프 삭제. 같은 차례에 항목을 숨기고 저장소 삭제 Task 를 시작해 돌려준다.
  /// 목록이 없거나, 없는 id 거나, 이미 삭제 중이면 무시하고 nil.
  @discardableResult
  public func deleteSwiped(id: UUID) -> Task<Void, Never>? {
    guard case .loaded = self.content, self.dDays.contains(where: { $0.id == id }),
          !self.deletingIDs.contains(id)
    else {
      return nil
    }
    self.deletingIDs.insert(id)
    self.rebuild()
    return Task { await self.finishDelete(id: id) }
  }

  public func deleteFailedAlertDismissed() {
    self.isDeleteFailedAlertPresented = false
  }

  /// 편집 화면이 저장함 (추가·수정·새로 저장). 저장소를 다시 읽지 않고 반영한다.
  /// 불러오기 실패 상태면 저장소가 열린다는 뜻이라 다시 불러오기를 시작해 그 Task 를 돌려준다. 그 밖에는 nil.
  /// 삭제 중인 id 면 값만 바꾸고 계속 숨긴다 (삭제가 실패하면 바뀐 값으로 돌아온다).
  @discardableResult
  public func dDaySaved(_ dDay: DDay) -> Task<Void, Never>? {
    switch self.content {
    case .loaded:
      Self.upsert(dDay, into: &self.dDays)
      self.rebuild()
      return nil
    case .loading:
      self.pendingEdits.append(.saved(dDay))
      return nil
    case .loadFailed:
      // 다시 읽은 결과에 저장된 값이 들어 있다. 겹친 다시 불러오기는 retryLoad 의 조건이 막는다.
      return Task { await self.retryLoad() }
    }
  }

  /// 편집 화면이 원래 디데이 대신 새로 저장함 (원래 id 는 저장소에 없다). 다시 읽지 않고 원래 항목을 빼고 새 항목을 넣는다.
  /// 불러오기 실패 상태면 다시 불러오기를 시작해 그 Task 를 돌려준다 (`dDaySaved` 와 같다). 그 밖에는 nil.
  /// 원래 id 가 삭제 중이어도 목록에서 빼므로 (`dDayDeleted` 와 같다) 홈 삭제가 실패해도 돌아오지 않는다.
  @discardableResult
  public func dDaySavedAsNew(_ dDay: DDay, replacing originalID: UUID) -> Task<Void, Never>? {
    switch self.content {
    case .loaded:
      self.dDays.removeAll { $0.id == originalID }
      Self.upsert(dDay, into: &self.dDays)
      self.rebuild()
      return nil
    case .loading:
      self.pendingEdits.append(.deleted(originalID))
      self.pendingEdits.append(.saved(dDay))
      return nil
    case .loadFailed:
      // 정상 흐름에선 오지 않는다 (수정은 .loaded 에서만 열린다). 다시 읽은 결과에 새 값이 들어 있다.
      return Task { await self.retryLoad() }
    }
  }

  /// 편집 화면이 지움. 저장소를 다시 읽지 않고 반영한다. 없는 id 는 무시한다.
  /// 불러오기 실패 상태면 목록이 없으므로 무시한다. 삭제 중인 id 면 목록에서만 빼서, 홈 삭제가 실패해도 돌아오지 않는다.
  public func dDayDeleted(id: UUID) {
    switch self.content {
    case .loaded:
      guard self.dDays.contains(where: { $0.id == id }) else { return }
      self.dDays.removeAll { $0.id == id }
      self.rebuild()
    case .loading:
      self.pendingEdits.append(.deleted(id))
    case .loadFailed:
      break
    }
  }

  // MARK: - Private

  private func load() async {
    self.isLoading = true
    defer {
      self.isLoading = false
      self.pendingEdits = []
    }
    do {
      var dDays = try await self.store.fetchAll()
      for edit in self.pendingEdits {
        switch edit {
        case let .saved(dDay): Self.upsert(dDay, into: &dDays)
        case let .deleted(id): dDays.removeAll { $0.id == id }
        }
      }
      self.dDays = dDays
      self.currentDay = self.today()
      self.rebuild()
    } catch {
      self.content = .loadFailed
    }
  }

  private func retryLoad() async {
    guard self.content == .loadFailed, !self.isLoading else { return }
    self.content = .loading
    await self.load()
  }

  private func refreshToday() {
    let day = self.today()
    guard day != self.currentDay else { return }
    self.currentDay = day
    if case .loaded = self.content {
      self.rebuild()
    }
  }

  private func finishDelete(id: UUID) async {
    do {
      try await self.store.delete(id: id)
      self.removeDeleted(id: id)
    } catch DDayStoreError.notFound {
      // 이미 없는 것은 원하는 결과다.
      self.removeDeleted(id: id)
    } catch {
      self.deletingIDs.remove(id)
      self.rebuild()
      self.isDeleteFailedAlertPresented = true
    }
  }

  /// 이미 숨긴 항목이라 화면은 바뀌지 않는다.
  private func removeDeleted(id: UUID) {
    self.dDays.removeAll { $0.id == id }
    self.deletingIDs.remove(id)
  }

  /// 같은 id 가 있으면 그 자리에서 바꾸고, 없으면 fetchAll 순서(생성 시각 → id 문자열)에 맞는 자리에 넣는다.
  private static func upsert(_ dDay: DDay, into dDays: inout [DDay]) {
    if let index = dDays.firstIndex(where: { $0.id == dDay.id }) {
      dDays[index] = dDay
      return
    }
    let index = dDays.firstIndex { existing in
      (existing.createdAt, existing.id.uuidString) > (dDay.createdAt, dDay.id.uuidString)
    } ?? dDays.endIndex
    dDays.insert(dDay, at: index)
  }

  /// `content` 의 목록은 여기서만 만든다. dDays 순서가 그대로라 삭제 실패로 돌아온 항목은 원래 자리에 놓인다.
  private func rebuild() {
    guard let day = self.currentDay else { return }
    let visible = self.dDays.filter { !self.deletingIDs.contains($0.id) }
    self.content = .loaded(
      DDayListOrder.entries(visible, today: day, schedule: \.schedule).map(HomeItem.init(entry:))
    )
  }
}

/// 불러오는 중에 온 편집 결과.
private enum PendingEdit {
  case saved(DDay)
  case deleted(UUID)
}
