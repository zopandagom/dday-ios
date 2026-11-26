import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

@MainActor
struct DDayEditorModelSaveTests {
  let recorder = OutcomeRecorder()

  @Test("추가 저장: 정리된 제목으로 저장하고 결과를 한 번 알린다")
  func addSaveSuccess() async throws {
    let fake = DDayStoreClientFake()
    let model = makeEditor(.add, store: fake, recorder: self.recorder)
    model.titleChanged("  기말고사 ")

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(fake.dDays.count == 1)
    #expect(saved.title == "기말고사")
    #expect(saved.schedule == DDaySchedule(date: .solar(EditorSample.today)))
    #expect(saved.reminder == .default)
    #expect(self.recorder.outcomes == [.saved(saved)])
    #expect(model.phase == .finished)
  }

  @Test("수정 저장은 같은 id 를 update 하고 생성 시각을 유지한다")
  func editSaveSuccessUpdates() async throws {
    let (model, fake) = makeEditEditor(recorder: self.recorder)
    model.titleChanged("아빠 생일")
    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: false)

    await model.saveButtonTapped()?.value

    let saved = try #require(fake.dDays.first)
    #expect(fake.dDays.count == 1)
    #expect(saved.id == EditorSample.originalID)
    #expect(saved.createdAt == EditorSample.createdAt)
    #expect(saved.title == "아빠 생일")
    #expect(saved.reminder.enabledDaysBefore == [0])
    #expect(saved.reminder.scheduledDaysBefore == [0])
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test("제목이 비면 저장하지 않는다")
  func saveIgnoredWhenTitleEmpty() {
    let store = ControlledEditorStore()
    let model = makeEditor(.add, store: store, recorder: self.recorder)
    model.titleChanged("  ")

    #expect(model.saveButtonTapped() == nil)

    #expect(store.calls.isEmpty)
    #expect(model.phase == .editing)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("저장은 같은 차례에 저장 중이 되고, 두 번째 호출은 무시한다")
  func saveSetsSavingSynchronously() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.add, store: store, recorder: self.recorder)
    model.titleChanged("제목")

    let task = model.saveButtonTapped()
    #expect(task != nil)
    #expect(model.phase == .saving)
    #expect(model.saveButtonTapped() == nil)

    try await store.waitForPendingWrite()
    try store.resumeWrite(with: .success(EditorSample.dDay(title: "제목")))
    await task?.value

    #expect(store.calls.count == 1)
    #expect(self.recorder.outcomes.count == 1)
  }

  @Test("저장 중에는 저장·새로 저장·취소·삭제·입력 이벤트를 모두 무시한다")
  func whileSavingEverythingIsIgnored() async throws {
    let store = ControlledEditorStore()
    // 기념일 토글 이벤트도 받는 D+ 방식으로 연다.
    let model = makeEditor(.edit(EditorSample.dDay(countingStyle: .dPlus)), store: store, recorder: self.recorder)
    model.titleChanged("바뀐 제목")
    let draft = model.draft

    let task = model.saveButtonTapped()
    #expect(model.isBusy)
    #expect(model.isDismissDisabled)
    #expect(!model.canSave)

    #expect(model.saveButtonTapped() == nil)
    #expect(model.saveAsNewTapped() == nil)
    #expect(model.deleteConfirmed() == nil)
    model.cancelButtonTapped()
    model.discardConfirmed()
    model.sheetDismissed()
    model.deleteButtonTapped()
    model.titleChanged("또 다른 제목")
    model.calendarKindChanged(.lunar)
    model.solarDayChanged(EditorSample.day(2030, 1, 1))
    model.repeatRuleChanged(.none)
    model.countingStyleChanged(.dDay)
    model.everyHundredDaysReminderChanged(false)
    model.anniversaryReminderChanged(false)
    model.reminderEnabledChanged(false)
    model.reminderDayEnabledChanged(daysBefore: 0, isEnabled: false)
    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: true)
    model.reminderTimeChanged(EditorSample.time(1, 0))

    #expect(model.draft == draft)
    #expect(!model.isDiscardConfirmationPresented)
    #expect(!model.isDeleteConfirmationPresented)
    #expect(model.phase == .saving)

    try await store.waitForPendingWrite()
    let saved = EditorSample.dDay(title: "바뀐 제목", countingStyle: .dPlus)
    try store.resumeWrite(with: .success(saved))
    await task?.value

    #expect(store.calls == [.update(EditorSample.originalID, draft)])
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  @Test(
    "저장 실패면 입력을 그대로 두고 저장 실패 알림창을 띄운다",
    arguments: [DDayStoreError.saveFailed, .loadFailed, .alreadyExists]
  )
  func saveFailureKeepsInput(error: DDayStoreError) async {
    let fake = DDayStoreClientFake()
    fake.failNextCall(with: error)
    let model = makeEditor(.add, store: fake, recorder: self.recorder)
    model.titleChanged("제목")
    let draft = model.draft

    await model.saveButtonTapped()?.value

    #expect(model.alert == .saveFailed)
    #expect(model.isAlertPresented)
    #expect(model.phase == .editing)
    #expect(model.title == "제목")
    #expect(model.draft == draft)
    #expect(model.canSave)
    #expect(fake.dDays.isEmpty)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("저장 실패 뒤 다시 저장하면 성공한다")
  func retryAfterSaveFailureSucceeds() async {
    let fake = DDayStoreClientFake()
    fake.failNextCall(with: .saveFailed)
    let model = makeEditor(.add, store: fake, recorder: self.recorder)
    model.titleChanged("제목")
    await model.saveButtonTapped()?.value
    model.alertDismissed()

    await model.saveButtonTapped()?.value

    #expect(fake.dDays.count == 1)
    #expect(self.recorder.outcomes.count == 1)
    #expect(model.phase == .finished)
  }

  @Test("저장 Task 를 취소해도 결과를 반영한다")
  func cancelledSaveTaskStillApplies() async throws {
    let store = ControlledEditorStore()
    let model = makeEditor(.add, store: store, recorder: self.recorder)
    model.titleChanged("제목")

    let task = model.saveButtonTapped()
    task?.cancel()
    try await store.waitForPendingWrite()
    let saved = EditorSample.dDay(title: "제목")
    try store.resumeWrite(with: .success(saved))
    await task?.value

    #expect(self.recorder.outcomes == [.saved(saved)])
    #expect(model.phase == .finished)
  }

  @Test("끝난 뒤의 이벤트는 모두 무시한다")
  func eventsAfterFinishedIgnored() {
    let (model, _) = makeEditEditor(recorder: self.recorder)
    model.cancelButtonTapped()
    #expect(self.recorder.outcomes == [.cancelled])

    #expect(model.saveButtonTapped() == nil)
    #expect(model.deleteConfirmed() == nil)
    model.cancelButtonTapped()
    model.discardConfirmed()
    model.sheetDismissed()
    model.titleChanged("바뀐 제목")

    #expect(self.recorder.outcomes == [.cancelled])
    #expect(model.title == "엄마 생일")
    #expect(model.phase == .finished)
  }
}
