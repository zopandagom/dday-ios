import Core
import Foundation

/// 알림 본문 문구. 모두 이 모듈의 `Localizable.xcstrings`(ko·en)에서 온다.
/// 키는 `reminder.` 으로 시작하는 문자열 리터럴로 쓰고, 값은 `\(String(…))` 로만 넣는다 (카탈로그 키의 `%@`).
/// 숫자를 문자열로 넘기는 것은 Int 보간(`%lld`)이 로캘 자릿수 구분("1,000일")을 붙이기 때문이다.
/// 두 값을 받는 키의 순서는 (기념일 숫자, N일 전) 이다.
enum ReminderText {
  /// 알림 본문을 앱 언어로 푼다. locale 을 넘기지 않는다: 화면 문구와 같은 번들 조회라 알림도 화면과 같은 언어가 된다
  /// (`Locale.current` 는 번들이 고른 언어와 다를 수 있다).
  static func body(_ kind: ReminderMessageKind) -> String {
    String(localized: self.bodyResource(kind))
  }

  /// 종류별 본문 (0 = 당일 문구).
  static func bodyResource(_ kind: ReminderMessageKind) -> LocalizedStringResource {
    switch kind {
    case let .target(daysBefore):
      if daysBefore == 0 {
        return self.resource("reminder.body.target.today")
      }
      return self.resource("reminder.body.target.daysBefore \(String(daysBefore))")
    case let .start(daysBefore):
      if daysBefore == 0 {
        return self.resource("reminder.body.start.today")
      }
      return self.resource("reminder.body.start.daysBefore \(String(daysBefore))")
    case let .daysSince(days, daysBefore):
      if daysBefore == 0 {
        return self.resource("reminder.body.daysSince.today \(String(days))")
      }
      return self.resource("reminder.body.daysSince.daysBefore \(String(days)) \(String(daysBefore))")
    case let .dayCount(day, daysBefore):
      if daysBefore == 0 {
        return self.resource("reminder.body.dayCount.today \(String(day))")
      }
      return self.resource("reminder.body.dayCount.daysBefore \(String(day)) \(String(daysBefore))")
    case let .anniversary(years, daysBefore):
      if daysBefore == 0 {
        return self.resource("reminder.body.anniversary.today \(String(years))")
      }
      return self.resource("reminder.body.anniversary.daysBefore \(String(years)) \(String(daysBefore))")
    }
  }

  /// 테스트용: 언어를 정해 푼다.
  static func localized(_ resource: LocalizedStringResource, locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
  }
}
