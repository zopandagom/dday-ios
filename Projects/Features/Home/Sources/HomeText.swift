import Core
import Foundation

/// 홈 화면 문구. 모두 이 모듈의 `Localizable.xcstrings`(ko·en)에서 온다.
/// 키는 `home.` 으로 시작하는 문자열 리터럴로 쓰고, 값은 `\(String(…))` 로만 넣는다 (카탈로그 키의 `%@`).
/// 숫자를 문자열로 넘기는 것은 Int 보간(`%lld`)이 로캘 자릿수 구분("2,027년", "Day 12,345")을 붙이기 때문이다.
enum HomeText {
  static var title: LocalizedStringResource { self.resource("home.title") }
  static var add: LocalizedStringResource { self.resource("home.add") }
  static var loading: LocalizedStringResource { self.resource("home.loading") }
  static var emptyTitle: LocalizedStringResource { self.resource("home.empty.title") }
  static var emptyMessage: LocalizedStringResource { self.resource("home.empty.message") }
  static var loadFailedTitle: LocalizedStringResource { self.resource("home.loadFailed.title") }
  static var loadFailedMessage: LocalizedStringResource { self.resource("home.loadFailed.message") }
  static var retry: LocalizedStringResource { self.resource("home.retry") }
  static var delete: LocalizedStringResource { self.resource("home.delete") }
  static var deleteFailedTitle: LocalizedStringResource { self.resource("home.deleteFailed.title") }
  static var deleteFailedMessage: LocalizedStringResource { self.resource("home.deleteFailed.message") }
  static var confirm: LocalizedStringResource { self.resource("home.confirm") }
  static var dateUnavailable: LocalizedStringResource { self.resource("home.date.unavailable") }
  static var detailEdit: LocalizedStringResource { self.resource("home.detail.edit") }
  static var detailDate: LocalizedStringResource { self.resource("home.detail.date") }
  static var detailFirstDate: LocalizedStringResource { self.resource("home.detail.firstDate") }
  static var detailRepeat: LocalizedStringResource { self.resource("home.detail.repeat") }
  static var detailCounting: LocalizedStringResource { self.resource("home.detail.counting") }
  static var detailFolder: LocalizedStringResource { self.resource("home.detail.folder") }
  static var filterAll: LocalizedStringResource { self.resource("home.filter.all") }
  static var folderManager: LocalizedStringResource { self.resource("home.folderManager") }
  static var filterEmptyFolderTitle: LocalizedStringResource { self.resource("home.filterEmpty.folderTitle") }
  static var filterEmptyUnfiledTitle: LocalizedStringResource { self.resource("home.filterEmpty.unfiledTitle") }
  static var filterEmptyFolderMessage: LocalizedStringResource { self.resource("home.filterEmpty.folderMessage") }
  static var filterEmptyUnfiledMessage: LocalizedStringResource { self.resource("home.filterEmpty.unfiledMessage") }

  /// 카드의 카운트 문구 ("D-3", "D-DAY", "D+10", "11일째").
  static func count(_ label: DDayCountLabel) -> LocalizedStringResource {
    switch label {
    case let .daysLeft(days):
      self.resource("home.count.daysLeft \(String(days))")
    case .dDay:
      self.resource("home.count.dDay")
    case let .daysPassed(days):
      self.resource("home.count.daysPassed \(String(days))")
    case let .dayNumber(number):
      self.resource("home.count.dayNumber \(String(number))")
    case .unavailable:
      self.resource("home.count.unavailable")
    }
  }

  /// 카드의 날짜 문구. 양력은 `locale` 의 긴 날짜 형식, 음력은 카탈로그 문구, 계산 불가는 안내 문구.
  static func dateText(_ date: DDayDate?, locale: Locale) -> String {
    switch date {
    case let .solar(day):
      self.solarText(day, locale: locale)
    case let .lunar(lunar):
      self.localized(
        lunar.isLeapMonth
          ? self.resource("home.date.lunarLeap \(String(lunar.year)) \(String(lunar.month)) \(String(lunar.day))")
          : self.resource("home.date.lunar \(String(lunar.year)) \(String(lunar.month)) \(String(lunar.day))"),
        locale: locale
      )
    case nil:
      self.localized(self.dateUnavailable, locale: locale)
    }
  }

  /// 상세의 반복 문구 (편집 화면의 `editor.repeat.*` 와 같은 값).
  static func repeatText(_ rule: RepeatRule) -> LocalizedStringResource {
    switch rule {
    case .none: self.resource("home.detail.repeat.none")
    case .yearly: self.resource("home.detail.repeat.yearly")
    }
  }

  /// 상세의 세는 방식 문구 (편집 화면의 `editor.counting.*` 와 같은 값).
  static func countingText(_ style: CountingStyle) -> LocalizedStringResource {
    switch style {
    case .dDay: self.resource("home.detail.counting.dDay")
    case .dPlus: self.resource("home.detail.counting.dPlus")
    case .dayOne: self.resource("home.detail.counting.dayOne")
    }
  }

  /// 상세에서 음력 날짜 아래에 붙이는 양력 줄 ("양력 2027년 2월 7일"). 양력 형식은 `dateText` 의 양력과 같다.
  static func detailSolarDate(_ day: CalendarDay, locale: Locale) -> String {
    self.localized(self.resource("home.detail.solarDate \(self.solarText(day, locale: locale))"), locale: locale)
  }

  /// 그 날의 GMT 자정을 GMT 로 형식화한다. 변환과 형식화가 같은 고정 시간대라 기기 시간대와 무관하게 하루 밀리지 않는다.
  private static func solarText(_ day: CalendarDay, locale: Locale) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
      return self.localized(self.dateUnavailable, locale: locale)
    }
    return date.formatted(Date.FormatStyle(
      date: .long,
      time: .omitted,
      locale: locale,
      calendar: calendar,
      timeZone: .gmt
    ))
  }

  private static func localized(_ resource: LocalizedStringResource, locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
  }
}
