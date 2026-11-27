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

  @Test("사진·자르기 문구 (ko·en)")
  func photoTexts() {
    let expected: [ExpectedText] = [
      ExpectedText(DDayEditorText.photoSection, "사진", "Photo"),
      ExpectedText(DDayEditorText.photoAdd, "사진 추가", "Add Photo"),
      ExpectedText(DDayEditorText.photoChange, "사진 바꾸기", "Change Photo"),
      ExpectedText(DDayEditorText.photoRemove, "사진 지우기", "Remove Photo"),
      ExpectedText(DDayEditorText.photoLoading, "사진을 불러오는 중…", "Loading photo…"),
      ExpectedText(DDayEditorText.photoPreview, "선택한 사진", "Selected photo"),
      ExpectedText(DDayEditorText.cropTitle, "사진 자르기", "Crop Photo"),
      ExpectedText(DDayEditorText.cropDone, "완료", "Done"),
      ExpectedText(DDayEditorText.cropHint, "끌어서 옮기고 두 손가락으로 확대하세요.", "Drag to move, pinch to zoom."),
      ExpectedText(
        DDayEditorText.cropRenderFailed,
        "사진을 만들지 못했어요. 다시 시도해 주세요.",
        "Couldn't prepare the photo. Please try again."
      ),
      ExpectedText(
        DDayEditorText.photoFooter(.loadFailed),
        "사진을 불러오지 못했어요. 다른 사진을 골라 주세요.",
        "Couldn't load this photo. Please choose another one."
      ),
      ExpectedText(
        DDayEditorText.photoFooter(.tooLarge),
        "사진이 너무 커서 쓸 수 없어요. 다른 사진을 골라 주세요.",
        "This photo is too large. Please choose another one."
      ),
      ExpectedText(DDayEditorText.photoFooter(nil), "사진은 이 기기에만 저장돼요.", "Photos are stored only on this device."),
      ExpectedText(
        DDayEditorText.photoFooter(.renderFailed),
        "사진은 이 기기에만 저장돼요.",
        "Photos are stored only on this device."
      ),
    ]
    for item in expected {
      #expect(self.text(item.resource, Self.korean) == item.korean)
      #expect(self.text(item.resource, Self.english) == item.english)
    }
  }

  @Test("이미 지워진 디데이 알림 본문: 저장된 사진도 잃었으면 사진 문구")
  func notFoundPhotoLostMessage() {
    #expect(self.text(DDayEditorText.alertMessage(.notFoundOnSave, isStoredPhotoLost: false), Self.korean)
      == "새로 저장할까요?")
    #expect(self.text(DDayEditorText.alertMessage(.notFoundOnSave, isStoredPhotoLost: true), Self.korean)
      == "이 디데이는 사진과 함께 이미 지워졌어요. 새로 저장하면 사진 없이 저장돼요.")
    #expect(self.text(DDayEditorText.alertMessage(.notFoundOnSave, isStoredPhotoLost: true), Self.english)
      == "This D-day and its photo were already deleted. Saving as new will save it without the photo.")
    #expect(self.text(DDayEditorText.alertMessage(.saveFailed, isStoredPhotoLost: true), Self.korean)
      == self.text(DDayEditorText.alertMessage(.saveFailed), Self.korean))
  }
}

/// 문구 하나의 기대값 (ko·en).
private struct ExpectedText {
  let resource: LocalizedStringResource
  let korean: String
  let english: String

  init(_ resource: LocalizedStringResource, _ korean: String, _ english: String) {
    self.resource = resource
    self.korean = korean
    self.english = english
  }
}
