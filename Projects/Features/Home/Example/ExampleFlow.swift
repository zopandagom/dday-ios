import Core
import DDayStoreInterface
import Foundation
import HomeFeature
import Observation

/// Example 의 화면 흐름(홈 → 상세 push → 흉내 편집). App 의 `AppFlow` 와 같은 규칙으로 홈·상세 모델을 잇는다.
/// 시나리오 하나마다 하나를 만들고 `ExampleSession` 이 들고 있다.
///
/// - 카드 탭은 상세를 연다. 상세가 떠 있는 동안 다시 열지 않는다 (두 번 탭·push 중 탭).
/// - 상세 [편집] 은 편집 화면 대신 흉내 확인창(`editingDDay`)을 띄운다. 고른 동작을 저장소에 실제로 하고,
///   성공하면 결과를 홈·상세 둘 다에 넘긴다 (실패하면 넘기지 않는다). 상세가 지워졌으면(`isRemoved`) 상세를 닫는다.
@MainActor
@Observable
final class ExampleFlow {
  /// 떠 있는 상세 하나. `==`·`hash` 는 세션 id 만 본다 (디데이 id 가 바뀌어도 다시 push 하지 않는다).
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
  /// 흉내 편집 확인창이 떠 있는 디데이 (상세 [편집] 을 누른 때의 값).
  private(set) var editingDDay: DDay?

  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay
  /// "사진 바꿔 저장" 이 고를 다음 색 순서.
  @ObservationIgnored private var nextPhotoColorIndex = 0

  init(store: any DDayStoreClient, today: @escaping @MainActor () -> CalendarDay) {
    // 홈 콜백이 self 를 강하게 잡지 않도록 약한 참조 상자를 넘기고 init 끝에서 채운다.
    let flowReference = WeakExampleFlowReference()
    self.store = store
    self.today = today
    self.homeModel = HomeModel(
      store: store,
      today: today,
      // Example 에는 추가 화면이 없다.
      onAddTapped: {},
      onDDaySelected: { flowReference.flow?.openDetail($0) }
    )
    flowReference.flow = self
  }

  /// 상세 바인딩의 set(nil): 뒤로 가기·스와이프로 닫힘. 이미 닫혔으면 아무것도 하지 않는다.
  func detailDismissed() {
    guard self.detail != nil else { return }
    self.detail = nil
    self.editingDDay = nil
  }

  /// 흉내 확인창이 닫힘 (취소·바깥 탭, 또는 동작 버튼 뒤).
  /// 동작 버튼은 확인창이 넘긴 디데이를 인자로 받으므로, 이 호출이 버튼 동작보다 먼저 와도 결과가 같다.
  func editDialogDismissed() {
    self.editingDDay = nil
  }

  /// "사진 바꿔 저장": 다음 색의 새 사진으로 바꾼다 (저장소가 새 사진 id 를 만든다).
  @discardableResult
  func replacePhotoTapped(_ dDay: DDay) -> Task<Void, Never> {
    let colors = Self.replacementColors[self.nextPhotoColorIndex % Self.replacementColors.count]
    self.nextPhotoColorIndex += 1
    let cardPhoto = ExamplePhotos.cardPhoto(colors.0, colors.1)
    return self.save(dDay) { $0.photo = .replace(cardPhoto) }
  }

  /// "사진 지워 저장".
  @discardableResult
  func removePhotoTapped(_ dDay: DDay) -> Task<Void, Never> {
    self.save(dDay) { $0.photo = .remove }
  }

  /// "제목 바꿔 저장": 사진은 그대로 두고 제목 끝에 "*" 를 붙인다.
  @discardableResult
  func renameTapped(_ dDay: DDay) -> Task<Void, Never> {
    self.save(dDay) { $0.title += "*" }
  }

  /// "삭제": 저장소에서 지운다. 이미 지워졌으면(`.notFound`) 편집 화면처럼 지워진 것으로 넘긴다.
  @discardableResult
  func deleteTapped(_ dDay: DDay) -> Task<Void, Never> {
    self.editingDDay = nil
    return Task { [weak self, store] in
      do throws(DDayStoreError) {
        try await store.delete(id: dDay.id)
      } catch {
        // 이미 지워짐(`.notFound`)은 지워진 것으로 넘기고, 그 밖의 실패는 결과를 넘기지 않는다.
        guard error == .notFound else { return }
      }
      self?.dDayDeleted(id: dDay.id)
    }
  }

  // MARK: - Private

  private static let replacementColors: [(ExamplePhotos.RGB, ExamplePhotos.RGB)] = [
    (.init(0.55, 0.75, 1), .init(0.8, 0.6, 1)),
    (.init(1, 0.6, 0.5), .init(1, 0.85, 0.4)),
    (.init(0.5, 0.85, 0.6), .init(0.4, 0.7, 0.9)),
  ]

  private func openDetail(_ dDay: DDay) {
    guard self.detail == nil else { return }
    let model = DDayDetailModel(
      dDay: dDay,
      store: self.store,
      today: self.today,
      onEditTapped: { [weak self] in self?.editingDDay = $0 }
    )
    self.detail = DetailSession(id: UUID(), model: model)
  }

  /// 확인창에 띄운 디데이(`dDay`)를 `change` 로 고친 내용으로 저장하고, 성공하면 결과를 넘긴다.
  private func save(_ dDay: DDay, _ change: (inout DDayDraft) -> Void) -> Task<Void, Never> {
    self.editingDDay = nil
    var draft = dDay.draft
    change(&draft)
    return Task { [weak self, store, draft] in
      guard let saved = try? await store.update(id: dDay.id, draft) else { return }
      self?.dDaySaved(saved)
    }
  }

  private func dDaySaved(_ dDay: DDay) {
    self.homeModel.dDaySaved(dDay)
    self.detail?.model.dDaySaved(dDay)
  }

  private func dDayDeleted(id: UUID) {
    self.homeModel.dDayDeleted(id: id)
    self.detail?.model.dDayDeleted(id: id)
    if self.detail?.model.isRemoved == true {
      self.detail = nil
    }
  }
}

/// `ExampleFlow` 를 약하게 가리키는 상자. 홈 콜백이 init 중에 만들어지므로 self 대신 이것을 잡는다.
@MainActor
private final class WeakExampleFlowReference {
  weak var flow: ExampleFlow?
}
