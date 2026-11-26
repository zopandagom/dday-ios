import Core
import Foundation
import Testing
@testable import HomeFeature

struct HomeTextTests {
  static let korean = Locale(identifier: "ko_KR")
  static let english = Locale(identifier: "en_US")

  func text(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
    var resource = resource
    resource.locale = locale
    return String(localized: resource)
  }

  @Test(
    "카운트 문구",
    arguments: [
      (DDayCountLabel.daysLeft(3), "D-3", "D-3"),
      (.dDay, "D-DAY", "D-DAY"),
      (.daysPassed(10), "D+10", "D+10"),
      (.dayNumber(1), "1일째", "Day 1"),
      (.dayNumber(11), "11일째", "Day 11"),
      (.unavailable, "확인 필요", "Check Date"),
    ]
  )
  func count(label: DDayCountLabel, korean: String, english: String) {
    #expect(self.text(HomeText.count(label), Self.korean) == korean)
    #expect(self.text(HomeText.count(label), Self.english) == english)
  }

  @Test(
    "큰 수에 자릿수 구분 기호를 넣지 않는다",
    arguments: [
      (DDayCountLabel.daysPassed(1234), "D+1234", "D+1234"),
      (.dayNumber(12345), "12345일째", "Day 12345"),
    ]
  )
  func largeNumbersHaveNoGrouping(label: DDayCountLabel, korean: String, english: String) {
    #expect(self.text(HomeText.count(label), Self.korean) == korean)
    #expect(self.text(HomeText.count(label), Self.english) == english)
  }

  @Test(
    "양력 날짜는 기기 시간대와 무관하게 그 날짜 그대로",
    arguments: [
      (2027, 2, 7, "2027년 2월 7일", "February 7, 2027"),
      (2026, 12, 31, "2026년 12월 31일", "December 31, 2026"),
      (2027, 1, 1, "2027년 1월 1일", "January 1, 2027"),
      (2028, 2, 29, "2028년 2월 29일", "February 29, 2028"),
    ]
  )
  func solarDate(year: Int, month: Int, day: Int, korean: String, english: String) throws {
    let date = try DDayDate.solar(#require(CalendarDay(year: year, month: month, day: day)))
    #expect(HomeText.dateText(date, locale: Self.korean) == korean)
    #expect(HomeText.dateText(date, locale: Self.english) == english)
  }

  @Test("음력 날짜와 윤달")
  func lunarDate() {
    let normal = DDayDate.lunar(LunarDate(year: 2027, month: 8, day: 15))
    let leap = DDayDate.lunar(LunarDate(year: 2025, month: 6, day: 1, isLeapMonth: true))

    #expect(HomeText.dateText(normal, locale: Self.korean) == "음력 2027년 8월 15일")
    #expect(HomeText.dateText(normal, locale: Self.english) == "Lunar 8/15/2027")
    #expect(HomeText.dateText(leap, locale: Self.korean) == "음력 2025년 윤6월 1일")
    #expect(HomeText.dateText(leap, locale: Self.english) == "Lunar leap 6/1/2025")
  }

  @Test("날짜가 없으면 지원하지 않는 날짜 문구")
  func unavailableDate() {
    #expect(HomeText.dateText(nil, locale: Self.korean) == "지원하지 않는 날짜예요")
    #expect(HomeText.dateText(nil, locale: Self.english) == "Unsupported date")
  }
}
