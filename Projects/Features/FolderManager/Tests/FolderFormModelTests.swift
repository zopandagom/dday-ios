import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import FolderManagerFeature

@MainActor
struct FolderFormModelTests {
  let recorder = FormRecorder()

  @Test("추가 처음 값: 빈 이름·Blush Pink·별, 저장할 수 없다")
  func addInitialState() {
    let model = self.recorder.makeForm(.add, store: DDayStoreClientFake())

    #expect(model.nameText.isEmpty)
    #expect(model.color == .blushPink)
    #expect(model.icon == .star)
    #expect(model.phase == .editing)
    #expect(model.nameValidation == .empty)
    #expect(!model.canSave)
    #expect(!model.isSaveFailedAlertPresented)
  }

  @Test("이름 입력: 유효·공백만·20자·21자")
  func nameValidation() {
    let model = self.recorder.makeForm(.add, store: DDayStoreClientFake())

    model.nameChanged("  여행 ")
    #expect(model.nameValidation == .valid("여행"))
    #expect(model.canSave)

    model.nameChanged("   ")
    #expect(model.nameValidation == .empty)
    #expect(!model.canSave)

    model.nameChanged(String(repeating: "가", count: 20))
    #expect(model.nameValidation == .valid(String(repeating: "가", count: 20)))
    #expect(model.canSave)

    model.nameChanged(String(repeating: "가", count: 21))
    #expect(model.nameValidation == .tooLong)
    #expect(!model.canSave)
  }

  @Test("nameLength 는 정리한 뒤 글자 수")
  func nameLength() {
    let model = self.recorder.makeForm(.add, store: DDayStoreClientFake())

    model.nameChanged(" 👨‍👩‍👧 가족 \n")

    #expect(model.nameLength == 4)
  }

  @Test("색·아이콘 선택")
  func colorAndIcon() {
    let model = self.recorder.makeForm(.add, store: DDayStoreClientFake())

    model.colorSelected(.mint)
    model.iconSelected(.airplane)

    #expect(model.color == .mint)
    #expect(model.icon == .airplane)
  }

  @Test("수정(기본 폴더): 처음 이름은 기본 이름 문자열, 색·아이콘은 폴더 값")
  func editSystemInitialState() {
    let model = self.recorder.makeForm(.edit(FolderSample.birthday), store: DDayStoreClientFake())

    #expect(model.nameText == "생일")
    #expect(model.color == FolderSample.birthday.color)
    #expect(model.icon == FolderSample.birthday.icon)
    #expect(model.canSave)
  }

  @Test("수정(기본 폴더): 이름을 그대로 두고 저장하면 .system 을 보내 기본 이름 유지")
  func editSystemKeepsSystemName() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    let model = self.recorder.makeForm(.edit(FolderSample.birthday), store: store)
    model.colorSelected(.butter)

    await model.saveButtonTapped()?.value

    let expected = DDayFolder(id: FolderSample.birthday.id, name: .system(.birthday), color: .butter, icon: .cake)
    #expect(self.recorder.outcomes == [.updated(expected)])
    #expect(store.folders.first == expected)
  }

  @Test("수정(기본 폴더): 이름을 바꿔 저장하면 .custom(정리값)")
  func editSystemRenamed() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    let model = self.recorder.makeForm(.edit(FolderSample.birthday), store: store)
    model.nameChanged(" 생일 파티 ")

    await model.saveButtonTapped()?.value

    #expect(store.folders.first?.name == .custom("생일 파티"))
  }

  @Test("수정(기본 폴더): 바꿨다가 앞뒤 공백을 붙여 되돌리면 .system")
  func editSystemRevertedWithSpaces() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeForm(.edit(FolderSample.birthday), store: store)
    model.nameChanged("생")
    model.nameChanged(" 생일  ")

    let task = try #require(model.saveButtonTapped())
    try await store.waitForPendingFolder()
    #expect(store.calls == [
      .update(
        FolderSample.birthday.id,
        DDayFolderDraft(name: .system(.birthday), color: FolderSample.birthday.color, icon: FolderSample.birthday.icon)
      ),
    ])
    try store.resumeFolder(with: .success(FolderSample.birthday))
    await task.value
  }

  @Test("수정(직접 만든 폴더): 처음 이름은 그 이름, 저장은 .custom")
  func editCustom() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeForm(.edit(FolderSample.travel), store: store)
    #expect(model.nameText == "여행")

    let task = try #require(model.saveButtonTapped())
    try await store.waitForPendingFolder()
    #expect(store.calls == [
      .update(FolderSample.travel.id, DDayFolderDraft(name: .custom("여행"), color: .mint, icon: .airplane)),
    ])
    try store.resumeFolder(with: .success(FolderSample.travel))
    await task.value

    #expect(self.recorder.outcomes == [.updated(FolderSample.travel)])
  }

  @Test("추가 저장: 같은 차례 saving, 성공하면 finished·onFinished(.added) 한 번, 그 뒤 이벤트 무시")
  func addSaves() async throws {
    let store = DDayStoreClientFake(folders: FolderSample.defaults, makeID: { FolderSample.id(777) })
    let model = self.recorder.makeForm(.add, store: store)
    model.nameChanged(" 여행 ")
    model.colorSelected(.mint)
    model.iconSelected(.airplane)

    let task = try #require(model.saveButtonTapped())
    #expect(model.phase == .saving)
    await task.value

    let saved = DDayFolder(id: FolderSample.id(777), name: .custom("여행"), color: .mint, icon: .airplane)
    #expect(model.phase == .finished)
    #expect(self.recorder.outcomes == [.added(saved)])
    #expect(store.folders.last == saved)

    model.nameChanged("다른 이름")
    model.colorSelected(.peach)
    #expect(model.saveButtonTapped() == nil)
    #expect(model.nameText == " 여행 ")
    #expect(model.color == .mint)
    #expect(self.recorder.outcomes.count == 1)
  }

  @Test("수정 저장: onFinished(.updated)")
  func editSaves() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    let model = self.recorder.makeForm(.edit(FolderSample.family), store: store)
    model.iconSelected(.gift)

    await model.saveButtonTapped()?.value

    let expected = DDayFolder(id: FolderSample.family.id, name: .system(.family), color: .mint, icon: .gift)
    #expect(self.recorder.outcomes == [.updated(expected)])
  }

  @Test("두 번 탭: 저장소 호출은 한 번, 저장 중 입력은 무시")
  func doubleTapAndInputWhileSaving() async throws {
    let store = ControlledFolderStore()
    let model = self.recorder.makeForm(.add, store: store)
    model.nameChanged("여행")

    let task = try #require(model.saveButtonTapped())
    #expect(model.saveButtonTapped() == nil)
    #expect(!model.canSave)
    model.nameChanged("시험")
    model.colorSelected(.butter)
    model.iconSelected(.book)
    try await store.waitForPendingFolder()
    #expect(store.calls.count == 1)
    #expect(model.nameText == "여행")
    #expect(model.color == .blushPink)
    #expect(model.icon == .star)

    try store.resumeFolder(with: .success(FolderSample.travel))
    await task.value
    #expect(store.calls.count == 1)
  }

  @Test(
    "실패: editing 으로 돌아오고 알림, 콜백 없음, 입력 그대로, 다시 저장하면 성공",
    arguments: [DDayStoreError.saveFailed, .loadFailed, .notFound, .invalidFolderName, .alreadyExists]
  )
  func failureThenRetry(error: DDayStoreError) async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    store.failNextCall(with: error)
    let model = self.recorder.makeForm(.edit(FolderSample.couple), store: store)
    model.nameChanged("우리")

    await model.saveButtonTapped()?.value

    #expect(model.phase == .editing)
    #expect(model.isSaveFailedAlertPresented)
    #expect(self.recorder.outcomes.isEmpty)
    #expect(model.nameText == "우리")
    #expect(store.folders == FolderSample.defaults)

    await model.saveButtonTapped()?.value

    #expect(model.phase == .finished)
    #expect(self.recorder.outcomes.count == 1)
    #expect(store.folders[2].name == .custom("우리"))
  }

  @Test("saveFailedAlertDismissed 는 알림을 끈다")
  func alertDismissed() async {
    let store = DDayStoreClientFake(folders: FolderSample.defaults)
    store.failNextCall(with: .saveFailed)
    let model = self.recorder.makeForm(.edit(FolderSample.other), store: store)
    await model.saveButtonTapped()?.value
    #expect(model.isSaveFailedAlertPresented)

    model.saveFailedAlertDismissed()

    #expect(!model.isSaveFailedAlertPresented)
  }
}
