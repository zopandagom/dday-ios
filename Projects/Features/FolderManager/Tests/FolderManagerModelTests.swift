import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import FolderManagerFeature

@MainActor
struct FolderManagerModelTests {
  let recorder = CallbackRecorder()

  private var defaultIDs: [UUID] {
    FolderSample.defaults.map(\.id)
  }

  // MARK: init·열기

  @Test("init 값: 받은 폴더·수, idle, 확인창·알림 없음")
  func initialState() {
    let counts = [FolderSample.birthday.id: 2]
    let model = self.recorder.makeManager(dDayCounts: counts, store: DDayStoreClientFake())

    #expect(model.folders == FolderSample.defaults)
    #expect(model.dDayCounts == counts)
    #expect(model.phase == .idle)
    #expect(!model.isBusy)
    #expect(model.pendingDeletion == nil)
    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.alert == nil)
    #expect(!model.isAlertPresented)
  }

  @Test("[새 폴더] 는 onAddTapped 를 부른다")
  func addButtonCallsBack() {
    let model = self.recorder.makeManager(store: DDayStoreClientFake())

    model.addButtonTapped()

    #expect(self.recorder.events == [.added])
  }

  @Test("행 탭은 그 폴더로 onEditTapped, 없는 id 는 무시")
  func folderTappedCallsBack() {
    let model = self.recorder.makeManager(store: DDayStoreClientFake())

    model.folderTapped(id: FolderSample.family.id)
    model.folderTapped(id: FolderSample.id(9999))

    #expect(self.recorder.events == [.edit(FolderSample.family)])
  }

  // MARK: 순서

  @Test("이동: 같은 차례에 새 순서·moving, 저장소가 받은 ids, 성공하면 반환값으로 바꾸고 콜백")
  func moveSucceeds() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)
    let expected = [FolderSample.family, FolderSample.couple, FolderSample.birthday, FolderSample.other]

    let task = try #require(model.foldersMoved(fromOffsets: [0], toOffset: 3))

    #expect(model.folders == expected)
    #expect(model.phase == .moving)
    #expect(model.isBusy)
    try await store.waitForPendingMove()
    #expect(store.calls == [.move(expected.map(\.id))])
    // 저장소 반환값을 그대로 쓴다.
    let returned = [FolderSample.family, FolderSample.couple, FolderSample.birthday, FolderSample.other]
    try store.resumeMove(with: .success(returned))
    await task.value

    #expect(model.folders == returned)
    #expect(model.phase == .idle)
    #expect(self.recorder.events == [.foldersChanged(returned)])
  }

  @Test("이동: Fake 저장소의 순서도 바뀐다")
  func moveUpdatesFake() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    let model = self.recorder.makeManager(store: store)

    await model.foldersMoved(fromOffsets: [3], toOffset: 0)?.value

    let expected = [FolderSample.other, FolderSample.birthday, FolderSample.family, FolderSample.couple]
    #expect(model.folders == expected)
    #expect(store.folders == expected)
  }

  @Test("같은 순서로 이동하면 저장소를 부르지 않는다")
  func sameOrderMoveIsIgnored() {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)

    #expect(model.foldersMoved(fromOffsets: [1], toOffset: 1) == nil)
    #expect(model.foldersMoved(fromOffsets: [1], toOffset: 2) == nil)
    #expect(model.foldersMoved(fromOffsets: [], toOffset: 0) == nil)

    #expect(store.calls.isEmpty)
    #expect(model.phase == .idle)
    #expect(model.folders == FolderSample.defaults)
  }

  @Test("이동 실패: 원래 순서로 되돌리고 알림, 콜백 없음", arguments: [DDayStoreError.saveFailed, .notFound, .loadFailed])
  func moveFailureRestores(error: DDayStoreError) async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)

    let task = try #require(model.foldersMoved(fromOffsets: [0], toOffset: 2))
    try await store.waitForPendingMove()
    try store.resumeMove(with: .failure(error))
    await task.value

    #expect(model.folders == FolderSample.defaults)
    #expect(model.phase == .idle)
    #expect(model.alert == .moveFailed)
    #expect(model.isAlertPresented)
    #expect(self.recorder.events.isEmpty)
  }

  @Test("이동 중에는 두 번째 이동·밀기·추가·행 탭·삭제를 무시한다")
  func busyIgnoresEvents() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeManager(store: store)

    let task = try #require(model.foldersMoved(fromOffsets: [0], toOffset: 2))
    try await store.waitForPendingMove()

    #expect(model.foldersMoved(fromOffsets: [1], toOffset: 4) == nil)
    model.deleteSwiped(id: FolderSample.family.id)
    model.addButtonTapped()
    model.folderTapped(id: FolderSample.family.id)
    #expect(model.deleteConfirmed(id: FolderSample.family.id, dDays: .delete) == nil)

    #expect(store.calls.count == 1)
    #expect(model.pendingDeletion == nil)
    #expect(!model.isDeleteConfirmationPresented)
    #expect(self.recorder.events.isEmpty)

    try store.resumeMove(with: .success(model.folders))
    await task.value
  }

  // MARK: 폼 결과

  @Test("formFinished(.added): 끝에 넣고 수 0·콜백, 같은 id 가 두 번 오면 한 번만")
  func formAdded() {
    let model = self.recorder.makeManager(store: DDayStoreClientFake())

    model.formFinished(.added(FolderSample.travel))
    model.formFinished(.added(FolderSample.travel))

    let expected = FolderSample.defaults + [FolderSample.travel]
    #expect(model.folders == expected)
    #expect(model.dDayCounts[FolderSample.travel.id] == 0)
    #expect(self.recorder.events == [.foldersChanged(expected)])
  }

  @Test("formFinished(.updated): 같은 자리 교체·콜백, 없는 id 는 무시")
  func formUpdated() {
    let model = self.recorder.makeManager(store: DDayStoreClientFake())
    let renamed = DDayFolder(id: FolderSample.family.id, name: .custom("우리 가족"), color: .butter, icon: .gift)

    model.formFinished(.updated(renamed))
    model.formFinished(.updated(FolderSample.travel))

    let expected = [FolderSample.birthday, renamed, FolderSample.couple, FolderSample.other]
    #expect(model.folders == expected)
    #expect(self.recorder.events == [.foldersChanged(expected)])
  }

  // MARK: 순서 계산

  @Test("moved 는 MutableCollection.move 와 같은 뜻 (설계 §1 의 6 사례)", arguments: [
    (IndexSet([0]), 2, [1, 0, 2, 3]),
    (IndexSet([0]), 4, [1, 2, 3, 0]),
    (IndexSet([3]), 0, [3, 0, 1, 2]),
    (IndexSet([1]), 1, [0, 1, 2, 3]),
    (IndexSet([1]), 2, [0, 1, 2, 3]),
    (IndexSet([0, 2]), 4, [1, 3, 0, 2]),
  ])
  func movedMatchesCollectionMove(offsets: IndexSet, destination: Int, expected: [Int]) {
    let ids = (0 ..< 4).map { FolderSample.id($0) }

    let result = FolderManagerModel.moved(ids, fromOffsets: offsets, toOffset: destination)

    #expect(result == expected.map { FolderSample.id($0) })
  }

  @Test("moved: 범위 밖 offset 은 무시하고 destination 은 clamp")
  func movedClamps() {
    let ids = (0 ..< 3).map { FolderSample.id($0) }

    #expect(FolderManagerModel.moved(ids, fromOffsets: [7], toOffset: 0) == ids)
    #expect(FolderManagerModel.moved(ids, fromOffsets: [0], toOffset: 99) == [1, 2, 0].map { FolderSample.id($0) })
  }
}
