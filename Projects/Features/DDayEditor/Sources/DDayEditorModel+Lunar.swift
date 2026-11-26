import Core
import Foundation

public extension DDayEditorModel {
  // MARK: - 음력 선택 이벤트 (음력일 때만, 고를 수 있는 값으로 맞춘다)

  func lunarYearChanged(_ year: Int) {
    self.changeLunar { LunarPickerOptions.normalized(
      year: year,
      month: $0.month,
      isLeapMonth: $0.isLeapMonth,
      day: $0.day
    ) }
  }

  func lunarMonthChanged(_ month: Int) {
    self.changeLunar { LunarPickerOptions.normalized(
      year: $0.year,
      month: month,
      isLeapMonth: $0.isLeapMonth,
      day: $0.day
    ) }
  }

  func lunarLeapMonthChanged(_ isLeapMonth: Bool) {
    self.changeLunar { LunarPickerOptions.normalized(
      year: $0.year,
      month: $0.month,
      isLeapMonth: isLeapMonth,
      day: $0.day
    ) }
  }

  func lunarDayChanged(_ day: Int) {
    self.changeLunar { LunarPickerOptions.normalized(
      year: $0.year,
      month: $0.month,
      isLeapMonth: $0.isLeapMonth,
      day: day
    ) }
  }
}
