import Core
import Foundation
import Testing
@testable import ReminderFeature

/// 알림 본문 10개 키의 ko·en 값 (실행 언어와 무관하게 locale 을 정해 푼다).
struct ReminderTextTests {
  static let korean = Locale(identifier: "ko_KR")
  static let english = Locale(identifier: "en_US")

  func text(_ kind: ReminderMessageKind, _ locale: Locale) -> String {
    ReminderText.localized(ReminderText.bodyResource(kind), locale: locale)
  }

  @Test(
    "종류별 본문",
    arguments: [
      (ReminderMessageKind.target(daysBefore: 0), "오늘이에요!", "It's today!"),
      (.target(daysBefore: 7), "7일 남았어요", "7 days to go"),
      (.start(daysBefore: 0), "오늘부터 시작이에요", "It starts today"),
      (.start(daysBefore: 2), "시작까지 2일 남았어요", "2 days until it starts"),
      (.daysSince(100, daysBefore: 0), "오늘로 100일이 됐어요", "It's been 100 days today"),
      (.daysSince(200, daysBefore: 7), "200일까지 7일 남았어요", "7 days to go until 200 days"),
      (.dayCount(100, daysBefore: 0), "오늘은 100일째 되는 날이에요", "Today is day 100"),
      (.dayCount(300, daysBefore: 30), "300일째까지 30일 남았어요", "30 days until day 300"),
      (.anniversary(years: 1, daysBefore: 0), "오늘은 1주년이에요", "Today is your 1-year anniversary"),
      (.anniversary(years: 3, daysBefore: 2), "3주년까지 2일 남았어요", "2 days until your 3-year anniversary"),
    ]
  )
  func body(kind: ReminderMessageKind, korean: String, english: String) {
    #expect(self.text(kind, Self.korean) == korean)
    #expect(self.text(kind, Self.english) == english)
  }

  @Test("숫자에 자릿수 구분이 없다")
  func numbersHaveNoGrouping() {
    #expect(self.text(.daysSince(1000, daysBefore: 0), Self.korean) == "오늘로 1000일이 됐어요")
    #expect(self.text(.daysSince(1000, daysBefore: 0), Self.english) == "It's been 1000 days today")
    #expect(self.text(.dayCount(1000, daysBefore: 30), Self.english) == "30 days until day 1000")
  }

  @Test("body 는 locale 없이 푼 값이다 (실행 언어의 문구)")
  func bodyUsesAppLanguage() {
    let kind = ReminderMessageKind.anniversary(years: 2, daysBefore: 7)
    #expect(ReminderText.body(kind) == String(localized: ReminderText.bodyResource(kind)))
    #expect([self.text(kind, Self.korean), self.text(kind, Self.english)].contains(ReminderText.body(kind)))
  }
}
