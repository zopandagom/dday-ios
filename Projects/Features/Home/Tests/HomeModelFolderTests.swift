import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// 폴더 불러오기·칩 필터·[+] 기본 폴더.
extension HomeModelTests {
  /// 폴더가 섞인 샘플. 전체 정렬: 2, 3, 1, 4, 5.
  /// 생일: 1, 5 / 가족: 2 / 연인: 없음 / 미분류: 3(nil), 4(없는 폴더).
  static let foldered: [DDay] = [
    HomeSample.dDay(1, HomeSample.solar(2026, 11, 29), folderID: HomeSample.birthday.id), // D-3
    HomeSample.dDay(2, HomeSample.solar(2026, 11, 26), folderID: HomeSample.family.id), // D-DAY
    HomeSample.dDay(3, HomeSample.solar(2026, 11, 27)), // D-1
    HomeSample.dDay(4, HomeSample.solar(2026, 12, 1), folderID: HomeSample.missingFolderID), // D-5
    HomeSample.dDay(5, HomeSample.solar(2026, 12, 6), folderID: HomeSample.birthday.id), // D-10
  ]

  static func ids(_ numbers: [Int]) -> [UUID] {
    numbers.map { HomeSample.id($0) }
  }

  /// 기본 폴더가 있는 Controlled 저장소로 `foldered` 를 불러온 모델.
  func loadedFolderModel(_ dDays: [DDay] = HomeModelTests.foldered) async throws -> (HomeModel, ControlledDDayStore) {
    let store = ControlledDDayStore(folders: HomeSample.folders)
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .success(dDays))
    return (model, store)
  }

  /// 폴더 읽기에서 멈춘 첫 불러오기.
  struct HeldFolderLoad {
    let model: HomeModel
    let store: ControlledDDayStore
    let task: Task<Void, Never>
  }

  /// 폴더 읽기를 멈추는 저장소로 첫 불러오기를 시작해, 디데이 읽기를 `dDays` 로 끝내고 폴더 읽기에서 멈춘 상태.
  func startLoadHoldingFolders(_ dDays: [DDay] = HomeModelTests.foldered) async throws -> HeldFolderLoad {
    let store = ControlledDDayStore(holdsFolderFetches: true)
    let model = self.makeModel(store: store)
    let task = Task { await model.onAppear() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(dDays))
    try await store.waitForPendingFolderFetches()
    return HeldFolderLoad(model: model, store: store, task: task)
  }

  // MARK: 불러오기

  @Test("불러오면 폴더는 fetchFolders 순서, 항목의 폴더는 목록에서 찾은 값 (없는 폴더·nil 은 미분류)")
  func loadResolvesFolders() async {
    let store = DDayStoreClientFake(dDays: Self.foldered, folders: HomeSample.folders)
    let model = self.makeModel(store: store)

    await model.onAppear()

    #expect(model.folders == HomeSample.folders)
    #expect(model.filter == .all)
    #expect(model.hasDDays)
    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
    #expect(model.content.items?.map(\.folder) == [
      HomeSample.family, nil, HomeSample.birthday, nil, HomeSample.birthday,
    ])
  }

  @Test("디데이 읽기가 실패하면 loadFailed 이고 폴더는 읽지 않는다")
  func fetchAllFailureSkipsFolders() async throws {
    let store = ControlledDDayStore(folders: HomeSample.folders)
    let model = self.makeModel(store: store)

    try await self.load(model, store, with: .failure(.loadFailed))

    #expect(model.content == .loadFailed)
    #expect(store.fetchFoldersCallCount == 0)
    #expect(model.folders.isEmpty)
  }

  @Test("디데이를 읽었어도 폴더 읽기가 실패하면 loadFailed, 다시 시도는 둘 다 다시 읽어 회복한다")
  func folderFailureThenRetryReadsBoth() async throws {
    let held = try await self.startLoadHoldingFolders()
    let (model, store, task) = (held.model, held.store, held.task)
    #expect(model.content == .loading)
    try store.resumeFolders(with: .failure(.loadFailed))
    await task.value
    #expect(model.content == .loadFailed)
    #expect(model.folders.isEmpty)
    #expect(model.hasDDays == false)

    let retry = Task { await model.retryButtonTapped() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(Self.foldered))
    try await store.waitForPendingFolderFetches()
    try store.resumeFolders(with: .success(HomeSample.folders))
    await retry.value

    #expect(store.fetchAllCallCount == 2)
    #expect(store.fetchFoldersCallCount == 2)
    #expect(model.folders == HomeSample.folders)
    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
  }

  @Test("폴더 읽기 실패 뒤 앱 복귀도 디데이·폴더 둘 다 다시 읽는다")
  func folderFailureThenSceneActiveReadsBoth() async throws {
    let held = try await self.startLoadHoldingFolders()
    let (model, store, task) = (held.model, held.store, held.task)
    try store.resumeFolders(with: .failure(.loadFailed))
    await task.value

    let active = Task { await model.sceneBecameActive() }
    try await store.waitForPendingFetches()
    try store.resumeFetch(with: .success(Self.foldered))
    try await store.waitForPendingFolderFetches()
    try store.resumeFolders(with: .success(HomeSample.folders))
    await active.value

    #expect(store.fetchAllCallCount == 2)
    #expect(store.fetchFoldersCallCount == 2)
    #expect(model.folders == HomeSample.folders)
    #expect(model.content.items?.first?.folder == HomeSample.family)
  }

  @Test("폴더를 읽는 동안 온 저장 결과는 불러오기 결과에 반영된다")
  func savedWhileFetchingFoldersIsApplied() async throws {
    let held = try await self.startLoadHoldingFolders()
    let (model, store, task) = (held.model, held.store, held.task)
    // 3 을 연인 폴더로 옮긴 저장 결과.
    let moved = HomeSample.dDay(3, HomeSample.solar(2026, 11, 27), folderID: HomeSample.couple.id)

    #expect(model.dDaySaved(moved) == nil)
    try store.resumeFolders(with: .success(HomeSample.folders))
    await task.value

    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
    #expect(model.content.items?[1].folder == HomeSample.couple)
    #expect(store.fetchAllCallCount == 1)
  }

  // MARK: filterSelected

  @Test("폴더 칩은 그 폴더의 디데이만 정렬 순서로 보인다")
  func filterFolder() async throws {
    let (model, _) = try await self.loadedFolderModel()

    model.filterSelected(.folder(HomeSample.birthday.id))

    #expect(model.filter == .folder(HomeSample.birthday.id))
    #expect(model.content.ids == Self.ids([1, 5]))
    #expect(model.content.items?.allSatisfy { $0.folder == HomeSample.birthday } == true)
  }

  @Test("미분류 칩은 폴더 없음과 목록에 없는 폴더를 가리키는 디데이를 보인다")
  func filterUnfiled() async throws {
    let (model, _) = try await self.loadedFolderModel()

    model.filterSelected(.unfiled)

    #expect(model.filter == .unfiled)
    #expect(model.content.ids == Self.ids([3, 4]))
  }

  @Test("전체 칩은 다시 모두 보인다")
  func filterAll() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.unfiled)

    model.filterSelected(.all)

    #expect(model.filter == .all)
    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
  }

  @Test("목록에 없는 폴더 칩은 무시한다")
  func filterUnknownFolderIgnored() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.family.id))

    model.filterSelected(.folder(HomeSample.missingFolderID))

    #expect(model.filter == .folder(HomeSample.family.id))
    #expect(model.content.ids == Self.ids([2]))
  }

  @Test("불러오는 중에는 칩을 무시한다")
  func filterWhileLoadingIgnored() async throws {
    let held = try await self.startLoadHoldingFolders()
    let (model, store, task) = (held.model, held.store, held.task)

    model.filterSelected(.unfiled)

    #expect(model.filter == .all)
    #expect(model.content == .loading)
    try store.resumeFolders(with: .success(HomeSample.folders))
    await task.value
    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
  }

  @Test("불러오기 실패 중에는 칩을 무시한다")
  func filterWhileFailedIgnored() async throws {
    let store = ControlledDDayStore(folders: HomeSample.folders)
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    model.filterSelected(.unfiled)

    #expect(model.filter == .all)
    #expect(model.content == .loadFailed)
  }

  @Test("필터 결과가 비면 빈 목록이고 디데이는 있다고 본다")
  func filterEmptyKeepsHasDDays() async throws {
    let (model, _) = try await self.loadedFolderModel()

    model.filterSelected(.folder(HomeSample.couple.id))

    #expect(model.content == .loaded([]))
    #expect(model.hasDDays)
  }

  @Test("디데이가 없으면 hasDDays 는 false")
  func noDDaysHasDDaysFalse() async throws {
    let (model, _) = try await self.loadedFolderModel([])

    #expect(model.content == .loaded([]))
    #expect(model.hasDDays == false)
    model.filterSelected(.unfiled)
    #expect(model.hasDDays == false)
  }

  // MARK: 필터 중 편집 결과

  @Test("필터 중 저장으로 폴더가 바뀌면 같은 차례에 빠지고, 그 폴더 필터에서는 들어온다")
  func savedFolderChangeMovesAcrossFilters() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.birthday.id))
    let moved = HomeSample.dDay(1, HomeSample.solar(2026, 11, 29), folderID: HomeSample.couple.id)

    model.dDaySaved(moved)

    #expect(model.content.ids == Self.ids([5]))
    model.filterSelected(.folder(HomeSample.couple.id))
    #expect(model.content.ids == Self.ids([1]))
    #expect(model.content.items?.first?.folder == HomeSample.couple)
  }

  @Test("필터 중 저장으로 그 폴더에 들어온 디데이는 같은 차례에 보인다")
  func savedIntoFilteredFolderAppears() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.family.id))
    let moved = HomeSample.dDay(3, HomeSample.solar(2026, 11, 27), folderID: HomeSample.family.id)

    model.dDaySaved(moved)

    #expect(model.content.ids == Self.ids([2, 3]))
  }

  @Test("필터 중 새로 저장은 원래 항목을 빼고 새 폴더 기준으로 거른다")
  func savedAsNewUnderFilter() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.unfiled)
    let replacement = HomeSample.dDay(8, HomeSample.solar(2026, 11, 28), folderID: HomeSample.family.id)

    model.dDaySavedAsNew(replacement, replacing: HomeSample.id(3))

    #expect(model.content.ids == Self.ids([4]))
    model.filterSelected(.folder(HomeSample.family.id))
    #expect(model.content.ids == Self.ids([2, 8]))
  }

  @Test("필터 중 편집 화면 삭제는 필터 결과에서 뺀다")
  func deletedUnderFilter() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.birthday.id))

    model.dDayDeleted(id: HomeSample.id(5))

    #expect(model.content.ids == Self.ids([1]))
    #expect(model.hasDDays)
  }

  @Test("필터 중 스와이프 삭제가 실패하면 필터 결과의 원래 자리로 돌아온다")
  func swipeDeleteFailureRestoresUnderFilter() async throws {
    let (model, store) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.birthday.id))

    let task = model.deleteSwiped(id: HomeSample.id(1))
    #expect(model.content.ids == Self.ids([5]))
    try await store.waitForPendingDelete(id: HomeSample.id(1))
    try store.resumeDelete(id: HomeSample.id(1), with: .failure(.saveFailed))
    await task?.value

    #expect(model.content.ids == Self.ids([1, 5]))
    #expect(model.isDeleteFailedAlertPresented)
  }

  @Test("필터 중 스와이프 삭제가 성공하면 빠진 채로 남고, 마지막 하나를 지우면 hasDDays 가 false")
  func swipeDeleteSuccessUnderFilter() async throws {
    let only = [HomeSample.dDay(1, HomeSample.solar(2026, 11, 29), folderID: HomeSample.birthday.id)]
    let (model, store) = try await self.loadedFolderModel(only)
    model.filterSelected(.folder(HomeSample.birthday.id))

    let task = model.deleteSwiped(id: HomeSample.id(1))
    #expect(model.content == .loaded([]))
    #expect(model.hasDDays == false)
    try await store.waitForPendingDelete(id: HomeSample.id(1))
    try store.resumeDelete(id: HomeSample.id(1), with: .success(()))
    await task?.value

    #expect(model.content == .loaded([]))
    #expect(model.filter == .folder(HomeSample.birthday.id))
  }

  // MARK: addButtonTapped

  @Test("폴더 필터에서 [+] 는 그 폴더 id, 전체·미분류는 nil")
  func addButtonPassesFilterFolder() async throws {
    let (model, _) = try await self.loadedFolderModel()

    model.addButtonTapped()
    model.filterSelected(.folder(HomeSample.family.id))
    model.addButtonTapped()
    model.filterSelected(.unfiled)
    model.addButtonTapped()

    #expect(self.recorder.addFolderIDs == [nil, HomeSample.family.id, nil])
  }

  @Test("불러오기 실패 중 [+] 는 nil")
  func addButtonWhileFailedPassesNil() async throws {
    let store = ControlledDDayStore(folders: HomeSample.folders)
    let model = self.makeModel(store: store)
    try await self.load(model, store, with: .failure(.loadFailed))

    model.addButtonTapped()

    #expect(self.recorder.addFolderIDs == [nil])
  }
}
