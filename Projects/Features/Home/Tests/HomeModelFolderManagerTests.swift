import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// [폴더 관리] 버튼·폴더 변경 반영·폴더별 디데이 수. 샘플·도우미는 HomeModelFolderTests.swift.
extension HomeModelTests {
  @Test("[폴더 관리] 는 목록이 있을 때만 콜백")
  func folderManagerButtonWhenLoaded() async throws {
    let (model, _) = try await self.loadedFolderModel()

    model.folderManagerButtonTapped()

    #expect(self.recorder.folderManagerTapCount == 1)
  }

  @Test("[폴더 관리] 는 불러오는 중·실패면 무시")
  func folderManagerButtonIgnoredWhenNotLoaded() async throws {
    let store = ControlledDDayStore(folders: HomeSample.folders)
    let model = self.makeModel(store: store)
    model.folderManagerButtonTapped()

    try await self.load(model, store, with: .failure(.loadFailed))
    model.folderManagerButtonTapped()

    #expect(model.content == .loadFailed)
    #expect(self.recorder.folderManagerTapCount == 0)
  }

  @Test("foldersChanged: 이름·색이 바뀐 폴더가 카드 폴더에 같은 차례에 반영")
  func foldersChangedRenames() async throws {
    let (model, _) = try await self.loadedFolderModel()
    let renamed = DDayFolder(id: HomeSample.birthday.id, name: .custom("파티"), color: .butter, icon: .gift)
    let folders = [renamed] + HomeSample.folders.dropFirst()

    model.foldersChanged(folders)

    #expect(model.folders == folders)
    #expect(model.content.items?.map(\.folder) == [HomeSample.family, nil, renamed, nil, renamed])
  }

  @Test("foldersChanged: 고른 칩 폴더가 지워지면 전체, 지운 폴더의 디데이는 미분류 칩에")
  func foldersChangedDeletesSelectedFolder() async throws {
    let (model, _) = try await self.loadedFolderModel()
    model.filterSelected(.folder(HomeSample.birthday.id))
    #expect(model.content.ids == Self.ids([1, 5]))

    model.foldersChanged(Array(HomeSample.folders.dropFirst()))

    #expect(model.filter == .all)
    #expect(model.content.ids == Self.ids([2, 3, 1, 4, 5]))
    model.filterSelected(.unfiled)
    #expect(model.content.ids == Self.ids([3, 1, 4, 5]))
  }

  @Test("foldersChanged: 새 폴더는 칩 순서에, 순서 변경은 folders 순서에")
  func foldersChangedAddsAndReorders() async throws {
    let (model, _) = try await self.loadedFolderModel()
    let travel = DDayFolder(id: HomeSample.id(501), name: .custom("여행"), color: .mint, icon: .airplane)

    model.foldersChanged(HomeSample.folders + [travel])
    #expect(model.folders.last == travel)
    model.filterSelected(.folder(travel.id))
    #expect(model.filter == .folder(travel.id))

    let reordered = [travel] + HomeSample.folders.reversed()
    model.foldersChanged(reordered)
    #expect(model.folders == reordered)
    #expect(model.filter == .folder(travel.id))
  }

  @Test("foldersChanged: 불러오는 중이면 무시")
  func foldersChangedIgnoredWhileLoading() {
    let model = self.makeModel(store: ControlledDDayStore(folders: HomeSample.folders))

    model.foldersChanged(HomeSample.folders)

    #expect(model.folders.isEmpty)
    #expect(model.content == .loading)
  }

  @Test("folderDDayCounts: 목록에 있는 폴더만, 삭제 중인 디데이는 빼고 센다")
  func folderDDayCounts() async throws {
    let (model, store) = try await self.loadedFolderModel()
    #expect(model.folderDDayCounts == [HomeSample.birthday.id: 2, HomeSample.family.id: 1])

    let task = model.deleteSwiped(id: HomeSample.id(5))
    #expect(model.folderDDayCounts == [HomeSample.birthday.id: 1, HomeSample.family.id: 1])

    try await store.waitForPendingDelete(id: HomeSample.id(5))
    try store.resumeDelete(id: HomeSample.id(5), with: .success(()))
    await task?.value
  }
}
