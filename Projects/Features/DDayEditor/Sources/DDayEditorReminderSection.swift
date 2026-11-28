import Core
import SwiftUI

/// 편집 화면의 알림 섹션: 켜기, 고정 알림 날짜 4개, 시각. `showsNotificationDeniedNotice` 면 footer 에 안내와 [설정 열기].
struct DDayEditorReminderSection: View {
  let model: DDayEditorModel
  @Environment(\.timeZone) private var timeZone

  var body: some View {
    Section {
      Toggle(isOn: Binding(
        get: { self.model.reminderIsEnabled },
        set: { self.model.reminderEnabledChanged($0) }
      )) {
        Text(DDayEditorText.reminderEnabled)
      }
      // 알림을 꺼도 날짜 값은 남는다 (숨기기만 한다).
      if self.model.reminderIsEnabled {
        ForEach(DDayEditorModel.reminderDayChoices, id: \.self) { daysBefore in
          Toggle(isOn: Binding(
            get: { self.model.enabledReminderDays.contains(daysBefore) },
            set: { self.model.reminderDayEnabledChanged(daysBefore: daysBefore, isEnabled: $0) }
          )) {
            Text(DDayEditorText.reminderDay(daysBefore))
          }
        }

        DatePicker(
          selection: Binding(
            get: { EditorDateConversion.date(from: self.model.reminderTime, in: self.timeZone) },
            set: { self.model.reminderTimeChanged(EditorDateConversion.timeOfDay(from: $0, in: self.timeZone)) }
          ),
          displayedComponents: .hourAndMinute
        ) {
          Text(DDayEditorText.reminderTime)
        }
      }
    } header: {
      Text(DDayEditorText.reminderSection)
    } footer: {
      if self.model.showsNotificationDeniedNotice {
        VStack(alignment: .leading, spacing: 8) {
          Text(DDayEditorText.notificationDenied)
          Button {
            self.model.notificationSettingsButtonTapped()
          } label: {
            Text(DDayEditorText.openNotificationSettings)
          }
        }
      }
    }
  }
}
