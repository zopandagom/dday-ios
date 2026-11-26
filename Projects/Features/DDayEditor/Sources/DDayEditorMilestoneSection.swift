import SwiftUI

/// 편집 화면의 기념일 알림 섹션: 100일마다·매년(N주년) 켜기.
/// 알림이 켜져 있고 D+·1일째 방식일 때만 알림 섹션 바로 아래에 보인다 (`DDayEditorView` 가 정한다).
struct DDayEditorMilestoneSection: View {
  let model: DDayEditorModel

  var body: some View {
    Section {
      Toggle(isOn: Binding(
        get: { self.model.remindsEveryHundredDays },
        set: { self.model.everyHundredDaysReminderChanged($0) }
      )) {
        Text(DDayEditorText.milestoneEveryHundredDays)
      }
      Toggle(isOn: Binding(
        get: { self.model.remindsAnniversaries },
        set: { self.model.anniversaryReminderChanged($0) }
      )) {
        Text(DDayEditorText.milestoneAnniversaries)
      }
    } header: {
      Text(DDayEditorText.milestoneSection)
    } footer: {
      Text(DDayEditorText.milestoneFooter)
    }
  }
}
