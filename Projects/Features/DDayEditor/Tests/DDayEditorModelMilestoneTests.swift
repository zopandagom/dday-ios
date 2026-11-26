import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayEditorFeature

/// 기념일 알림 토글 (100일마다·매년). D+·1일째 방식에서만 보이고 바꿀 수 있으며, 값은 늘 저장한다.
@MainActor
struct DDayEditorModelMilestoneTests {
  enum MilestoneToggle: CaseIterable {
    case everyHundredDays
    case anniversaries
  }

  func change(_ toggle: MilestoneToggle, _ isOn: Bool, on model: DDayEditorModel) {
    switch toggle {
    case .everyHundredDays: model.everyHundredDaysReminderChanged(isOn)
    case .anniversaries: model.anniversaryReminderChanged(isOn)
    }
  }

  func value(_ toggle: MilestoneToggle, in reminder: ReminderSettings) -> Bool {
    switch toggle {
    case .everyHundredDays: reminder.remindsEveryHundredDays
    case .anniversaries: reminder.remindsAnniversaries
    }
  }

  @Test(
    "기념일 알림은 D+·1일째 방식에서만 보인다",
    arguments: [(CountingStyle.dDay, false), (.dPlus, true), (.dayOne, true)]
  )
  func milestoneRemindersShownOnlyForDPlusAndDayOne(style: CountingStyle, expected: Bool) {
    let model = makeEditor(.add)

    model.countingStyleChanged(style)

    #expect(model.showsMilestoneReminders == expected)
  }

  @Test("기념일 토글을 바꾸면 저장값에 반영되고, 되돌리면 변경 없음이다", arguments: MilestoneToggle.allCases)
  func milestoneToggleChanged(toggle: MilestoneToggle) {
    let (model, _) = makeEditEditor(EditorSample.dDay(countingStyle: .dPlus))
    #expect(self.value(toggle, in: model.draft.reminder))

    self.change(toggle, false, on: model)
    #expect(!self.value(toggle, in: model.draft.reminder))
    #expect(model.remindsEveryHundredDays == (toggle != .everyHundredDays))
    #expect(model.remindsAnniversaries == (toggle != .anniversaries))
    #expect(model.hasChanges)

    self.change(toggle, true, on: model)
    #expect(self.value(toggle, in: model.draft.reminder))
    #expect(!model.hasChanges)
  }

  @Test("D-day 방식에서는 기념일 토글 이벤트를 무시하고 값은 남는다")
  func milestoneTogglesIgnoredForDDayStyle() {
    let (model, _) = makeEditEditor(EditorSample.dDay(countingStyle: .dDay))

    model.everyHundredDaysReminderChanged(false)
    model.anniversaryReminderChanged(false)

    #expect(model.remindsEveryHundredDays)
    #expect(model.remindsAnniversaries)
    #expect(model.draft.reminder.remindsEveryHundredDays)
    #expect(model.draft.reminder.remindsAnniversaries)
    #expect(!model.hasChanges)
  }

  @Test("세는 방식을 바꿔도 기념일 토글은 그대로이고, D-day 일 때도 저장값에 남는다")
  func countingStyleChangeKeepsMilestoneToggles() {
    let (model, _) = makeEditEditor(EditorSample.dDay(countingStyle: .dPlus))
    model.everyHundredDaysReminderChanged(false)

    model.countingStyleChanged(.dDay)
    #expect(!model.showsMilestoneReminders)
    #expect(!model.remindsEveryHundredDays)
    #expect(!model.draft.reminder.remindsEveryHundredDays)
    #expect(model.draft.reminder.remindsAnniversaries)

    model.countingStyleChanged(.dPlus)
    #expect(model.showsMilestoneReminders)
    #expect(!model.remindsEveryHundredDays)
    #expect(model.remindsAnniversaries)
  }
}
