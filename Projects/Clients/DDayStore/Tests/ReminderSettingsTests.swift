import Core
import DDayStoreInterface
import Testing

struct ReminderSettingsTests {
  @Test("며칠 전 목록은 음수를 버리고 중복을 하나로 합쳐 오름차순으로 둔다")
  func normalizesDaysBefore() {
    let settings = ReminderSettings(daysBefore: [7, -1, 2, 7, 0], time: Sample.time(9, 0))
    #expect(settings.daysBefore == [0, 2, 7])
  }

  @Test("빈 목록은 빈 목록 그대로 둔다")
  func keepsEmptyDaysBefore() {
    let settings = ReminderSettings(daysBefore: [], time: Sample.time(9, 0))
    #expect(settings.daysBefore.isEmpty)
    #expect(settings.isEnabled)
  }

  @Test("기본값은 켜짐, 당일·2일 전·7일 전, 오전 9시다")
  func defaultSettings() {
    let settings = ReminderSettings.default
    #expect(settings.isEnabled)
    #expect(settings.daysBefore == [0, 2, 7])
    #expect(settings.time == Sample.time(9, 0))
  }
}
