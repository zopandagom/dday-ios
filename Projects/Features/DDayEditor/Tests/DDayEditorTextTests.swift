import Core
import Foundation
import Testing
@testable import DDayEditorFeature

struct DDayEditorTextTests {
  static let korean = Locale(identifier: "ko_KR")
  static let english = Locale(identifier: "en_US")

  func text(_ resource: LocalizedStringResource, _ locale: Locale) -> String {
    DDayEditorText.localized(resource, locale: locale)
  }

  @Test(
    "알림 날짜 이름",
    arguments: [
      (0, "당일", "On the day"),
      (2, "2일 전", "2 days before"),
      (7, "7일 전", "7 days before"),
      (30, "30일 전", "30 days before"),
    ]
  )
  func reminderDayLabels(daysBefore: Int, korean: String, english: String) {
    #expect(self.text(DDayEditorText.reminderDay(daysBefore), Self.korean) == korean)
    #expect(self.text(DDayEditorText.reminderDay(daysBefore), Self.english) == english)
  }

  @Test("음력 날짜와 윤달 (Home 과 같은 모양)")
  func lunarDateText() {
    let normal = EditorSample.lunar(2027, 8, 15)
    let leap = EditorSample.lunar(2025, 6, 29, leap: true)

    #expect(self.text(DDayEditorText.lunarDate(normal), Self.korean) == "음력 2027년 8월 15일")
    #expect(self.text(DDayEditorText.lunarDate(normal), Self.english) == "Lunar 8/15/2027")
    #expect(self.text(DDayEditorText.lunarDate(leap), Self.korean) == "음력 2025년 윤6월 29일")
    #expect(self.text(DDayEditorText.lunarDate(leap), Self.english) == "Lunar leap 6/29/2025")
  }

  @Test("날짜 아래 환산 줄: 양력은 음력으로, 음력은 양력으로")
  func convertedDateText() {
    let solar = DDayDate.solar(EditorSample.day(2025, 8, 22))
    let lunar = DDayDate.lunar(EditorSample.lunar(2025, 6, 29, leap: true))

    #expect(DDayEditorText.convertedDateText(solar, locale: Self.korean) == "음력 2025년 윤6월 29일")
    #expect(DDayEditorText.convertedDateText(lunar, locale: Self.korean) == "2025년 8월 22일")
    #expect(DDayEditorText.convertedDateText(lunar, locale: Self.english) == "August 22, 2025")
  }

  @Test("숫자에 자릿수 구분 기호를 넣지 않는다")
  func numbersHaveNoGrouping() {
    #expect(self.text(DDayEditorText.yearValue(2025), Self.korean) == "2025년")
    #expect(self.text(DDayEditorText.yearValue(2025), Self.english) == "2025")
    #expect(self.text(DDayEditorText.monthValue(11), Self.korean) == "11월")
    #expect(self.text(DDayEditorText.dayValue(30), Self.korean) == "30일")
  }

  @Test("세는 방식·반복·달력 이름 (ko·en)")
  func countingRepeatCalendarLabels() {
    #expect(self.text(DDayEditorText.counting(.dDay), Self.korean) == "남은 날 (D-day)")
    #expect(self.text(DDayEditorText.counting(.dPlus), Self.english) == "Days since (D+)")
    #expect(self.text(DDayEditorText.counting(.dayOne), Self.korean) == "시작일을 1일로")
    #expect(self.text(DDayEditorText.repeatRule(.none), Self.korean) == "반복 없음")
    #expect(self.text(DDayEditorText.repeatRule(.yearly), Self.english) == "Every year")
    #expect(self.text(DDayEditorText.calendarKind(.solar), Self.korean) == "양력")
    #expect(self.text(DDayEditorText.calendarKind(.lunar), Self.english) == "Lunar")
  }

  @Test("기념일 알림 섹션 문구 (ko·en)")
  func milestoneLabels() {
    #expect(self.text(DDayEditorText.milestoneSection, Self.korean) == "기념일 알림")
    #expect(self.text(DDayEditorText.milestoneSection, Self.english) == "Milestone Reminders")
    #expect(self.text(DDayEditorText.milestoneEveryHundredDays, Self.korean) == "100일마다")
    #expect(self.text(DDayEditorText.milestoneEveryHundredDays, Self.english) == "Every 100 Days")
    #expect(self.text(DDayEditorText.milestoneAnniversaries, Self.korean) == "매년 (N주년)")
    #expect(self.text(DDayEditorText.milestoneAnniversaries, Self.english) == "Every Year (Anniversary)")
    #expect(self.text(DDayEditorText.milestoneFooter, Self.korean)
      == "100일·200일… 과 N주년에도 위 알림 날짜와 시간에 맞춰 알려 드려요.")
    #expect(self.text(DDayEditorText.milestoneFooter, Self.english)
      == "Also reminds you for every 100th day and each anniversary, on the days and at the time above.")
  }

  @Test("알림창 제목·메시지")
  func alertTexts() {
    #expect(self.text(DDayEditorText.alertTitle(.notFoundOnSave), Self.korean) == "이미 지워진 디데이예요")
    #expect(self.text(DDayEditorText.alertMessage(.notFoundOnSave), Self.korean) == "새로 저장할까요?")
    #expect(self.text(DDayEditorText.alertTitle(.saveFailed), Self.korean) == "저장하지 못했어요")
    #expect(self.text(DDayEditorText.alertTitle(nil), Self.english) == "Couldn't Save")
    #expect(self.text(DDayEditorText.alertTitle(.deleteFailed), Self.english) == "Couldn't Delete")
  }
}
