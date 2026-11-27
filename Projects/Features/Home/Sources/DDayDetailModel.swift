import Core
import DDayStoreInterface
import Foundation
import Observation

/// 디데이 상세 화면의 상태와 로직. App(또는 Example)이 홈 카드 탭에서 만들어 소유하고, 편집 결과를 홈과 이 모델 둘 다에 넘긴다.
///
/// - 사진의 압축본은 나타날 때 `fetchPhoto(id:)` 로 한 번 읽는다. 실패(`.failed`)한 읽기만 앱 복귀 때 한 번 다시 읽는다.
///   읽는 중·nil·실패면 화면은 썸네일을 보인다. 압축본 디코딩은 View 가 한다 (Model 은 `Data` 만 둔다).
/// - "오늘"은 주입한 `today` 로 구하고, 앱 복귀·날짜 변경·시간대 변경 때 다시 구해 바뀌었을 때만 카운트를 다시 계산한다.
/// - 편집 결과: 같은 디데이의 저장은 내용을 바꾸고 사진 id 가 바뀌면 압축본을 다시 읽는다. 원래 id 를 대신한 새로 저장은
///   새 디데이로 바꾼다. 지금 보는 디데이가 지워지면 `isRemoved` 가 되고 App 이 상세를 닫는다.
///
/// 불변식:
/// - I1: `largePhoto == nil` ⇔ `dDay.photo == nil`. `largePhoto` 는 **지금** `dDay.photo` 의 상태다 (사진 id 가 바뀌는
///   같은 차례에 바꾼다). 예외: 편집 저장과 압축본 읽기가 저장소에서 겹치면, 옛 사진 id 로 시작한 읽기가 저장 뒤 상태를 읽어
///   새 사진의 Data(또는 짝 불일치 nil → `.unavailable`)를 받을 수 있다. 저장소가 압축본과 함께 사진 id 를 돌려주지 않아
///   가려낼 수 없다. 이 어긋남은 곧 오는 `dDaySaved`(같은 저장의 결과)가 키를 바꿔 다시 읽을 때까지만이다.
/// - I2: 읽기 결과는 시작할 때의 키(디데이 id·사진 id)가 지금 키와 같고 지워지지 않았을 때만 반영한다. 취소 대신 키로 거른다
///   (저장소는 취소를 보지 않는다).
/// - I3: 한 키에 동시에 도는 읽기는 하나다 (`onAppear` 는 `.notLoaded`, `sceneBecameActive` 는 `.failed` 일 때만,
///   저장 결과는 키가 바뀔 때만 읽기를 시작한다).
/// - I4: `isRemoved` 가 true 면 모든 이벤트가 아무것도 하지 않는다. `dDay`·`largePhoto` 는 마지막 값 그대로다
///   (닫히는 애니메이션 동안 화면이 바뀌지 않게).
@MainActor
@Observable
public final class DDayDetailModel {
  /// 지금 사진(`dDay.photo`)의 압축본 상태. 사진이 없으면 `largePhoto` 는 nil.
  public enum LargePhoto: Equatable, Sendable {
    /// 아직 읽지 않음 (썸네일 표시)
    case notLoaded
    /// 읽는 중 (썸네일)
    case loading
    /// 압축본 JPEG (View 가 디코딩, 그 전·실패는 썸네일)
    case loaded(Data)
    /// `fetchPhoto` 가 nil (압축본 행 없음·짝 불일치) → 썸네일, 다시 읽지 않음
    case unavailable
    /// `fetchPhoto` 가 던짐 → 썸네일, 앱 복귀 때 한 번 다시 읽음
    case failed
  }

  /// 읽기 결과를 거르는 키. 디데이 id 나 사진 id 가 바뀌면 옛 결과는 버린다.
  private struct PhotoKey: Equatable {
    let dDayID: UUID
    let photoID: UUID
  }

  public private(set) var dDay: DDay
  public private(set) var status: DDayStatus
  public private(set) var largePhoto: LargePhoto?
  /// 지금 보는 디데이가 지워짐(편집 화면 삭제·이미 지워짐). 한 번 true 면 그대로. App 이 보고 상세를 닫는다.
  public private(set) var isRemoved = false

  /// 마지막 카운트 계산에 쓴 오늘.
  private var currentDay: CalendarDay

  @ObservationIgnored private let store: any DDayStoreClient
  @ObservationIgnored private let today: @MainActor () -> CalendarDay
  @ObservationIgnored private let onEditTapped: @MainActor (DDay) -> Void

  public init(
    dDay: DDay,
    store: any DDayStoreClient,
    today: @escaping @MainActor () -> CalendarDay,
    onEditTapped: @escaping @MainActor (DDay) -> Void
  ) {
    let day = today()
    self.dDay = dDay
    self.currentDay = day
    self.status = DDayStatus(schedule: dDay.schedule, today: day)
    self.largePhoto = dDay.photo == nil ? nil : .notLoaded
    self.store = store
    self.today = today
    self.onEditTapped = onEditTapped
  }

  private var currentKey: PhotoKey? {
    self.dDay.photo.map { PhotoKey(dDayID: self.dDay.id, photoID: $0.id) }
  }

  // MARK: - Events

  /// 처음 나타날 때 압축본을 읽는다. 아직 읽지 않았을 때만 같은 차례에 `.loading` 으로 바꾸고 읽기 Task 를 돌려준다. 그 밖에는 nil.
  @discardableResult
  public func onAppear() -> Task<Void, Never>? {
    guard !self.isRemoved, self.largePhoto == .notLoaded else { return nil }
    return self.startLoading()
  }

  /// 앱이 다시 활성화됨: 오늘을 다시 구하고, 압축본 읽기에 실패한 상태면 한 번 다시 읽어 그 Task 를 돌려준다. 그 밖에는 nil.
  @discardableResult
  public func sceneBecameActive() -> Task<Void, Never>? {
    guard !self.isRemoved else { return nil }
    self.refreshToday()
    guard self.largePhoto == .failed else { return nil }
    return self.startLoading()
  }

  /// 날짜·시간대가 바뀜: 오늘을 다시 구한다 (저장소는 읽지 않는다).
  public func calendarDayChanged() {
    guard !self.isRemoved else { return }
    self.refreshToday()
  }

  /// 지금 값(저장 뒤면 바뀐 값)으로 편집을 연다.
  public func editButtonTapped() {
    guard !self.isRemoved else { return }
    self.onEditTapped(self.dDay)
  }

  /// 편집 화면이 저장함. 지금 보는 디데이면 내용을 바꾸고, 사진 id 가 바뀌거나 새로 생기면 같은 차례에 `.loading` 으로 바꾸고
  /// 새 압축본 읽기 Task 를 돌려준다. 사진이 같으면 압축본 상태는 그대로(읽는 중이면 그 결과가 반영된다), 지우면 nil.
  /// 다른 디데이거나 지워진 뒤면 무시하고 nil.
  @discardableResult
  public func dDaySaved(_ dDay: DDay) -> Task<Void, Never>? {
    guard !self.isRemoved, dDay.id == self.dDay.id else { return nil }
    return self.replace(with: dDay)
  }

  /// 편집 화면이 원래 디데이 대신 새로 저장함. 원래 id 가 지금 보는 디데이면 새 디데이로 바꾸고, 사진이 있으면 새 id 로
  /// 압축본을 읽는 Task 를 돌려준다. 다른 디데이거나 지워진 뒤면 무시하고 nil.
  @discardableResult
  public func dDaySavedAsNew(_ dDay: DDay, replacing originalID: UUID) -> Task<Void, Never>? {
    guard !self.isRemoved, originalID == self.dDay.id else { return nil }
    return self.replace(with: dDay)
  }

  /// 편집 화면이 지움(이미 지워짐 포함). 지금 보는 디데이면 `isRemoved` 로 두고 나머지는 그대로 둔다.
  public func dDayDeleted(id: UUID) {
    guard !self.isRemoved, id == self.dDay.id else { return }
    self.isRemoved = true
  }

  // MARK: - Private

  /// 디데이를 바꾸고 카운트를 다시 계산한다. 키가 바뀌면 압축본 상태를 새 사진에 맞춘다 (I1). 옛 읽기 결과는 키가 달라 버려진다 (I2).
  private func replace(with dDay: DDay) -> Task<Void, Never>? {
    let oldKey = self.currentKey
    self.dDay = dDay
    self.status = DDayStatus(schedule: dDay.schedule, today: self.currentDay)
    guard self.currentKey != oldKey else { return nil }
    guard self.currentKey != nil else {
      self.largePhoto = nil
      return nil
    }
    return self.startLoading()
  }

  /// 같은 차례에 `.loading` 으로 바꾸고 지금 키로 읽기를 시작한다.
  private func startLoading() -> Task<Void, Never>? {
    guard let key = self.currentKey else { return nil }
    self.largePhoto = .loading
    return Task { await self.load(key) }
  }

  private func load(_ key: PhotoKey) async {
    let result: LargePhoto
    do {
      result = try await self.store.fetchPhoto(id: key.dDayID).map { .loaded($0) } ?? .unavailable
    } catch {
      // `.notFound` 도 실패로 둔다: 지워졌는지는 편집 결과(`dDayDeleted`)로만 안다.
      result = .failed
    }
    guard !self.isRemoved, key == self.currentKey else { return }
    self.largePhoto = result
  }

  private func refreshToday() {
    let day = self.today()
    guard day != self.currentDay else { return }
    self.currentDay = day
    self.status = DDayStatus(schedule: self.dDay.schedule, today: day)
  }
}
