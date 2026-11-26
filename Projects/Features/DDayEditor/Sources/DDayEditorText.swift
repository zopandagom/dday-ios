import Core
import Foundation

/// 편집 화면 문구. 모두 이 모듈의 `Localizable.xcstrings`(ko·en)에서 온다.
/// 키는 `editor.` 으로 시작하는 문자열 리터럴로 쓰고, 값은 `\(String(…))` 로만 넣는다 (카탈로그 키의 `%@`).
/// 숫자를 문자열로 넘기는 것은 Int 보간(`%lld`)이 로캘 자릿수 구분("2,025년")을 붙이기 때문이다.
enum DDayEditorText {
  static var addTitle: LocalizedStringResource { self.resource("editor.title.add") }
  static var editTitle: LocalizedStringResource { self.resource("editor.title.edit") }
  static var cancel: LocalizedStringResource { self.resource("editor.cancel") }
  static var save: LocalizedStringResource { self.resource("editor.save") }
  static var fieldTitle: LocalizedStringResource { self.resource("editor.field.title") }
  static var titleEmpty: LocalizedStringResource { self.resource("editor.title.empty") }
  static var dateSection: LocalizedStringResource { self.resource("editor.section.date") }
  static var lunarYear: LocalizedStringResource { self.resource("editor.lunar.year") }
  static var lunarMonth: LocalizedStringResource { self.resource("editor.lunar.month") }
  static var lunarLeapMonth: LocalizedStringResource { self.resource("editor.lunar.leapMonth") }
  static var lunarDay: LocalizedStringResource { self.resource("editor.lunar.day") }
  static var dateAdjusted: LocalizedStringResource { self.resource("editor.date.adjusted") }
  static var repeatSection: LocalizedStringResource { self.resource("editor.section.repeat") }
  static var countingSection: LocalizedStringResource { self.resource("editor.section.counting") }
  static var reminderSection: LocalizedStringResource { self.resource("editor.section.reminder") }
  static var reminderEnabled: LocalizedStringResource { self.resource("editor.reminder.enabled") }
  static var reminderTime: LocalizedStringResource { self.resource("editor.reminder.time") }
  static var milestoneSection: LocalizedStringResource { self.resource("editor.section.milestones") }
  static var milestoneEveryHundredDays: LocalizedStringResource { self.resource("editor.milestone.everyHundredDays") }
  static var milestoneAnniversaries: LocalizedStringResource { self.resource("editor.milestone.anniversaries") }
  static var milestoneFooter: LocalizedStringResource { self.resource("editor.milestone.footer") }
  static var delete: LocalizedStringResource { self.resource("editor.delete") }
  static var deleteConfirmTitle: LocalizedStringResource { self.resource("editor.delete.confirm.title") }
  static var deleteConfirmAction: LocalizedStringResource { self.resource("editor.delete.confirm.action") }
  static var discardTitle: LocalizedStringResource { self.resource("editor.discard.title") }
  static var discardAction: LocalizedStringResource { self.resource("editor.discard.action") }
  static var keepEditing: LocalizedStringResource { self.resource("editor.discard.keepEditing") }
  static var saveAsNew: LocalizedStringResource { self.resource("editor.notFound.saveAsNew") }
  static var confirm: LocalizedStringResource { self.resource("editor.confirm") }

  static func calendarKind(_ kind: DDayEditorModel.CalendarKind) -> LocalizedStringResource {
    switch kind {
    case .solar: self.resource("editor.calendar.solar")
    case .lunar: self.resource("editor.calendar.lunar")
    }
  }

  static func repeatRule(_ rule: RepeatRule) -> LocalizedStringResource {
    switch rule {
    case .none: self.resource("editor.repeat.none")
    case .yearly: self.resource("editor.repeat.yearly")
    }
  }

  static func counting(_ style: CountingStyle) -> LocalizedStringResource {
    switch style {
    case .dDay: self.resource("editor.counting.dDay")
    case .dPlus: self.resource("editor.counting.dPlus")
    case .dayOne: self.resource("editor.counting.dayOne")
    }
  }

  /// 알림 날짜 이름 (0 = 당일, 그 밖 = N일 전).
  static func reminderDay(_ daysBefore: Int) -> LocalizedStringResource {
    switch daysBefore {
    case 0: self.resource("editor.reminder.onTheDay")
    default: self.resource("editor.reminder.daysBefore \(String(daysBefore))")
    }
  }

  /// 음력 선택기의 연·월·일 값.
  static func yearValue(_ year: Int) -> LocalizedStringResource {
    self.resource("editor.lunar.yearValue \(String(year))")
  }

  static func monthValue(_ month: Int) -> LocalizedStringResource {
    self.resource("editor.lunar.monthValue \(String(month))")
  }

  static func dayValue(_ day: Int) -> LocalizedStringResource {
    self.resource("editor.lunar.dayValue \(String(day))")
  }

  /// 음력 날짜 ("음력 2025년 윤6월 29일", "Lunar leap 6/29/2025").
  static func lunarDate(_ lunar: LunarDate) -> LocalizedStringResource {
    lunar.isLeapMonth
      ? self.resource("editor.date.lunarLeap \(String(lunar.year)) \(String(lunar.month)) \(String(lunar.day))")
      : self.resource("editor.date.lunar \(String(lunar.year)) \(String(lunar.month)) \(String(lunar.day))")
  }

  /// 날짜 아래 환산 줄: 양력이면 같은 날의 음력, 음력이면 같은 날의 양력. 변환할 수 없으면 nil.
  static func convertedDateText(_ date: DDayDate, locale: Locale) -> String? {
    switch date {
    case let .solar(day):
      guard let lunar = KoreanLunarCalendar.lunarDate(from: day) else { return nil }
      return self.localized(self.lunarDate(lunar), locale: locale)
    case let .lunar(lunar):
      guard let day = KoreanLunarCalendar.solarDay(from: lunar) else { return nil }
      return self.solarText(day, locale: locale)
    }
  }

  /// 그 날의 GMT 자정을 GMT 로 형식화한다 (Home 과 같은 방식). 기기 시간대와 무관하게 하루 밀리지 않는다.
  static func solarText(_ day: CalendarDay, locale: Locale) -> String? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
      return nil
    }
    return date.formatted(Date.FormatStyle(
      date: .long,
      time: .omitted,
      locale: locale,
      calendar: calendar,
      timeZone: .gmt
    ))
  }

  /// 알림창 제목. 띄운 적이 없으면(nil) 저장 실패 제목 (보이지 않는다).
  static func alertTitle(_ alert: DDayEditorModel.Alert?) -> LocalizedStringResource {
    switch alert {
    case .saveFailed, nil: self.resource("editor.saveFailed.title")
    case .notFoundOnSave: self.resource("editor.notFound.title")
    case .deleteFailed: self.resource("editor.deleteFailed.title")
    }
  }

  static func alertMessage(_ alert: DDayEditorModel.Alert) -> LocalizedStringResource {
    switch alert {
    case .saveFailed: self.resource("editor.saveFailed.message")
    case .notFoundOnSave: self.resource("editor.notFound.message")
    case .deleteFailed: self.resource("editor.deleteFailed.message")
    }
  }

  static func localized(_ resource: LocalizedStringResource, locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
  }
}
