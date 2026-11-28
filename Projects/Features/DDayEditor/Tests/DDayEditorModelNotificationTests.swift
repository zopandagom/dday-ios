import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

/// [설정 열기] 콜백 횟수.
@MainActor
final class SettingsTapRecorder {
  var count = 0
}

/// 알림 권한 거부 안내: `isNotificationDenied`·`showsNotificationDeniedNotice`·[설정 열기]·권한 변경.
@MainActor
struct DDayEditorModelNotificationTests {
  let recorder = OutcomeRecorder()
  let settings = SettingsTapRecorder()

  func makeModel(
    _ mode: DDayEditorMode = .add,
    store: any DDayStoreClient = DDayStoreClientFake(),
    isDenied: Bool
  ) -> DDayEditorModel {
    let settings = self.settings
    return makeEditor(
      mode,
      store: store,
      isNotificationDenied: isDenied,
      onNotificationSettingsTapped: { settings.count += 1 },
      recorder: self.recorder
    )
  }

  // MARK: 안내 표시

  @Test("거부 상태이고 알림과 알림 날짜(기본)가 켜져 있으면 안내가 보인다")
  func noticeShownWhenDeniedAndEnabled() {
    let model = self.makeModel(isDenied: true)

    #expect(model.isNotificationDenied)
    #expect(model.reminderIsEnabled)
    #expect(model.showsNotificationDeniedNotice)
  }

  @Test("거부 상태여도 알림을 끄면 안내가 사라지고, 다시 켜면 보인다")
  func noticeFollowsReminderToggle() {
    let model = self.makeModel(isDenied: true)

    model.reminderEnabledChanged(false)
    #expect(!model.showsNotificationDeniedNotice)

    model.reminderEnabledChanged(true)
    #expect(model.showsNotificationDeniedNotice)
  }

  @Test("거부 상태여도 알림 날짜를 모두 끄면 안내가 사라지고, 하나를 켜면 보인다 (예약 기준과 같다)")
  func noticeFollowsReminderDays() {
    let model = self.makeModel(isDenied: true)

    for daysBefore in model.enabledReminderDays {
      model.reminderDayEnabledChanged(daysBefore: daysBefore, isEnabled: false)
    }
    #expect(model.reminderIsEnabled)
    #expect(model.enabledReminderDays.isEmpty)
    #expect(!model.showsNotificationDeniedNotice)

    model.reminderDayEnabledChanged(daysBefore: 30, isEnabled: true)
    #expect(model.showsNotificationDeniedNotice)
  }

  @Test("거부 상태가 아니면 안내가 없다 (기본값도 거부 아님)")
  func noticeHiddenWhenNotDenied() {
    let model = self.makeModel(isDenied: false)
    let defaultModel = makeEditor(.add)

    #expect(!model.showsNotificationDeniedNotice)
    #expect(!defaultModel.isNotificationDenied)
    #expect(!defaultModel.showsNotificationDeniedNotice)
  }

  @Test("수정 모드에서 알림을 끈 디데이는 거부 상태여도 안내가 없다")
  func noticeHiddenForDisabledReminderInEditMode() {
    let dDay = EditorSample.dDay(reminder: ReminderSettings(
      isEnabled: false,
      enabledDaysBefore: [0],
      time: EditorSample.time(9, 0)
    ))
    let model = self.makeModel(.edit(dDay), store: DDayStoreClientFake(dDays: [dDay]), isDenied: true)

    #expect(!model.showsNotificationDeniedNotice)
  }

  // MARK: notificationSettingsButtonTapped

  @Test("거부 상태에서 [설정 열기] 는 콜백을 한 번 부르고 편집 상태는 그대로다")
  func settingsTappedCallsBack() {
    let model = self.makeModel(isDenied: true)

    model.notificationSettingsButtonTapped()

    #expect(self.settings.count == 1)
    #expect(model.phase == .editing)
    #expect(!model.hasChanges)
    #expect(self.recorder.outcomes.isEmpty)
  }

  @Test("거부 상태가 아니면 [설정 열기] 를 무시한다")
  func settingsTappedIgnoredWhenNotDenied() {
    let model = self.makeModel(isDenied: false)

    model.notificationSettingsButtonTapped()

    #expect(self.settings.count == .zero)
  }

  @Test("끝난 뒤의 [설정 열기] 는 무시한다")
  func settingsTappedIgnoredAfterFinish() {
    let model = self.makeModel(isDenied: true)
    model.cancelButtonTapped()
    #expect(model.phase == .finished)

    model.notificationSettingsButtonTapped()

    #expect(self.settings.count == .zero)
  }

  @Test("저장 중에도 [설정 열기] 를 받고 저장은 끝까지 돈다")
  func settingsTappedWhileSaving() async throws {
    let store = ControlledEditorStore()
    let model = self.makeModel(store: store, isDenied: true)
    model.titleChanged("시험")
    let task = model.saveButtonTapped()
    #expect(model.phase == .saving)

    model.notificationSettingsButtonTapped()
    #expect(self.settings.count == 1)

    try await store.waitForPendingWrite()
    let saved = EditorSample.dDay(title: "시험")
    try store.resumeWrite(with: .success(saved))
    await task?.value
    #expect(self.recorder.outcomes == [.saved(saved)])
  }

  // MARK: notificationAuthorizationChanged(isDenied:)

  @Test("거부가 풀리면 안내가 사라지고 변경으로 보지 않는다")
  func authorizationChangedToAllowed() {
    let model = self.makeModel(isDenied: true)

    model.notificationAuthorizationChanged(isDenied: false)

    #expect(!model.isNotificationDenied)
    #expect(!model.showsNotificationDeniedNotice)
    #expect(!model.hasChanges)
    #expect(!model.isDismissDisabled)
  }

  @Test("열린 동안 거부되면 알림을 켜 둔 경우 안내가 나타나고, 그 뒤 [설정 열기] 를 받는다")
  func authorizationChangedToDenied() {
    let model = self.makeModel(isDenied: false)

    model.notificationAuthorizationChanged(isDenied: true)

    #expect(model.isNotificationDenied)
    #expect(model.showsNotificationDeniedNotice)
    #expect(!model.hasChanges)
    model.notificationSettingsButtonTapped()
    #expect(self.settings.count == 1)
  }

  @Test("끝난 뒤의 권한 변경은 무시한다")
  func authorizationChangedIgnoredAfterFinish() {
    let model = self.makeModel(isDenied: true)
    model.sheetDismissed()
    #expect(model.phase == .finished)

    model.notificationAuthorizationChanged(isDenied: false)

    #expect(model.isNotificationDenied)
  }

  @Test("저장 중에도 권한 변경 값은 바뀌고 저장 값에는 들어가지 않는다")
  func authorizationChangedWhileSaving() async throws {
    let store = ControlledEditorStore()
    let model = self.makeModel(store: store, isDenied: true)
    model.titleChanged("시험")
    let draft = model.draft
    let task = model.saveButtonTapped()

    model.notificationAuthorizationChanged(isDenied: false)
    #expect(!model.isNotificationDenied)

    try await store.waitForPendingWrite()
    #expect(store.calls == [.add(draft)])
    let saved = EditorSample.dDay(title: "시험")
    try store.resumeWrite(with: .success(saved))
    await task?.value
    #expect(self.recorder.outcomes == [.saved(saved)])
  }
}
