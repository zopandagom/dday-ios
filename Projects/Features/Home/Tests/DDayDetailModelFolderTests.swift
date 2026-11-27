import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

/// 상세의 폴더: 열 때 받은 목록에서 지금 디데이의 폴더를 찾는다.
@MainActor
struct DDayDetailModelFolderTests {
  let clock = TestDayClock()

  func makeModel(_ dDay: DDay, folders: [DDayFolder] = HomeSample.folders) -> DDayDetailModel {
    let clock = self.clock
    return DDayDetailModel(
      dDay: dDay,
      folders: folders,
      store: DDayStoreClientFake(dDays: [dDay], folders: folders),
      today: { clock.day },
      onEditTapped: { _ in }
    )
  }

  /// 폴더 없는 사진 없는 디데이 (D-1).
  func dDay(_ number: Int = 1, folderID: UUID?) -> DDay {
    HomeSample.dDay(number, HomeSample.solar(2026, 11, 27), folderID: folderID)
  }

  // MARK: init

  @Test("목록에 있는 폴더면 그 폴더")
  func initFolderInList() {
    let model = self.makeModel(self.dDay(folderID: HomeSample.family.id))

    #expect(model.folders == HomeSample.folders)
    #expect(model.folder == HomeSample.family)
  }

  @Test("목록에 없는 폴더면 nil (미분류)")
  func initFolderMissing() {
    let model = self.makeModel(self.dDay(folderID: HomeSample.missingFolderID))

    #expect(model.folder == nil)
  }

  @Test("폴더가 nil 이면 nil")
  func initNoFolder() {
    let model = self.makeModel(self.dDay(folderID: nil))

    #expect(model.folder == nil)
  }

  @Test("폴더 목록을 받지 않으면(빈 목록) 폴더가 있어도 nil")
  func initWithoutFolderList() {
    let model = self.makeModel(self.dDay(folderID: HomeSample.family.id), folders: [])

    #expect(model.folders.isEmpty)
    #expect(model.folder == nil)
  }

  // MARK: 편집 결과

  @Test("저장으로 폴더가 바뀌면 같은 차례에 폴더가 바뀐다")
  func dDaySavedChangesFolder() {
    let model = self.makeModel(self.dDay(folderID: HomeSample.family.id))

    model.dDaySaved(self.dDay(folderID: HomeSample.couple.id))
    #expect(model.folder == HomeSample.couple)

    model.dDaySaved(self.dDay(folderID: nil))
    #expect(model.folder == nil)
  }

  @Test("새로 저장은 새 디데이의 폴더")
  func dDaySavedAsNewUsesNewFolder() {
    let model = self.makeModel(self.dDay(folderID: nil))

    model.dDaySavedAsNew(self.dDay(2, folderID: HomeSample.birthday.id), replacing: HomeSample.id(1))

    #expect(model.dDay.id == HomeSample.id(2))
    #expect(model.folder == HomeSample.birthday)
  }

  @Test("다른 디데이의 저장은 폴더를 바꾸지 않는다")
  func otherDDaySavedKeepsFolder() {
    let model = self.makeModel(self.dDay(folderID: HomeSample.family.id))

    model.dDaySaved(self.dDay(2, folderID: HomeSample.couple.id))

    #expect(model.folder == HomeSample.family)
  }
}
