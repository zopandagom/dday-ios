import Core
import DDayStoreInterface
import Foundation
import Testing
@testable import DDayStoreImpl

struct DDayRecordMappingTests {
  private static let createdAt = Date(timeIntervalSince1970: 1_700_000_000.25)
  private static let updatedAt = Date(timeIntervalSince1970: 1_800_000_000.5)

  private static func dDay(
    _ draft: DDayDraft,
    createdAt: Date = Self.createdAt,
    updatedAt: Date = Self.updatedAt
  ) -> DDay {
    DDay(
      id: Sample.id(1),
      title: draft.title,
      schedule: draft.schedule,
      reminder: draft.reminder,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  /// 2025년 음력은 윤6월이 있고(`KoreanLunarCalendar.leapMonth(in: 2025) == 6`), 2026년 음력 1월은 30일까지 있다.
  static let roundTripCases: [DDay] = [
    Self.dDay(Sample.draft(date: Sample.solar(2026, 11, 26))),
    Self.dDay(Sample.draft(date: Sample.solar(2024, 2, 29))),
    Self.dDay(Sample.draft(date: Sample.lunar(2026, 1, 1))),
    Self.dDay(Sample.draft(date: Sample.lunar(2025, 6, 15, leap: true))),
    Self.dDay(Sample.draft(date: Sample.lunar(2026, 1, 30))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(
      isEnabled: false,
      enabledDaysBefore: [2, 7],
      time: Sample.time(20, 30)
    ))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(
      isEnabled: true,
      enabledDaysBefore: [],
      time: Sample.time(9, 0)
    ))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(enabledDaysBefore: [0], time: Sample.time(23, 59)))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(enabledDaysBefore: [0, 30], time: Sample.time(0, 0)))),
    Self.dDay(Sample.draft(reminder: .default)),
    Self.dDay(Sample.draft(reminder: ReminderSettings(enabledDaysBefore: [0, 2, 7, 30], time: Sample.time(9, 0)))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(enabledDaysBefore: [30], time: Sample.time(9, 0)))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(
      isEnabled: false,
      enabledDaysBefore: [],
      time: Sample.time(9, 0)
    ))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(
      enabledDaysBefore: [0, 2, 7],
      time: Sample.time(9, 0),
      remindsEveryHundredDays: false
    ))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(
      isEnabled: false,
      enabledDaysBefore: [0],
      time: Sample.time(9, 0),
      remindsEveryHundredDays: false,
      remindsAnniversaries: false
    ))),
    Self.dDay(Sample.draft(""), createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: -1)),
  ]

  @Test("저장값으로 바꿨다가 다시 읽으면 같은 디데이다", arguments: Self.roundTripCases)
  func roundTrip(dDay: DDay) {
    #expect(DDayRecordMapping.dDay(from: DDayRecordMapping.fields(of: dDay)) == dDay)
  }

  @Test(
    "반복 방식과 세는 방식의 모든 조합이 왕복한다",
    arguments: RepeatRule.allCases,
    CountingStyle.allCases
  )
  func roundTripRules(repeatRule: RepeatRule, countingStyle: CountingStyle) {
    for date in [Sample.solar(2026, 3, 1), Sample.lunar(2025, 6, 1, leap: true)] {
      let dDay = Self.dDay(Sample.draft(date: date, repeatRule: repeatRule, countingStyle: countingStyle))
      #expect(DDayRecordMapping.dDay(from: DDayRecordMapping.fields(of: dDay)) == dDay)
    }
  }

  @Test("쓰기는 리터럴 저장 문자열을 쓴다 (V1 저장 형식 고정)")
  func storedStrings() {
    let solar = DDayRecordMapping.fields(of: Self.dDay(Sample.draft(date: Sample.solar(2026, 11, 26))))
    #expect(solar.dateKind == "solar")
    #expect(solar.dateIsLeapMonth == false)
    #expect((solar.dateYear, solar.dateMonth, solar.dateDay) == (2026, 11, 26))

    let lunar = DDayRecordMapping.fields(of: Self.dDay(Sample.draft(date: Sample.lunar(2025, 6, 15, leap: true))))
    #expect(lunar.dateKind == "lunar")
    #expect(lunar.dateIsLeapMonth == true)

    #expect(DDayRecordMapping.string(for: RepeatRule.none) == "none")
    #expect(DDayRecordMapping.string(for: RepeatRule.yearly) == "yearly")
    #expect(DDayRecordMapping.string(for: CountingStyle.dDay) == "dDay")
    #expect(DDayRecordMapping.string(for: CountingStyle.dPlus) == "dPlus")
    #expect(DDayRecordMapping.string(for: CountingStyle.dayOne) == "dayOne")
  }

  private static var validFields: DDayRecordFields {
    DDayRecordMapping.fields(of: dDay(Sample.draft(date: Sample.solar(2026, 11, 26))))
  }

  @Test("모르는 날짜 종류는 읽지 못한다", arguments: ["gregorian", "", "Solar"])
  func unknownDateKind(value: String) {
    var fields = Self.validFields
    fields.dateKind = value
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("모르는 반복 방식은 읽지 못한다", arguments: ["Yearly", "monthly", ""])
  func unknownRepeatRule(value: String) {
    var fields = Self.validFields
    fields.repeatRule = value
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("모르는 세는 방식은 읽지 못한다", arguments: ["DDay", "dplus", ""])
  func unknownCountingStyle(value: String) {
    var fields = Self.validFields
    fields.countingStyle = value
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("없는 양력 날짜는 읽지 못한다", arguments: [(2025, 2, 29), (2026, 13, 1), (0, 1, 1)])
  func invalidSolarDate(year: Int, month: Int, day: Int) {
    var fields = Self.validFields
    (fields.dateYear, fields.dateMonth, fields.dateDay) = (year, month, day)
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("양력인데 윤달 표시가 있으면 읽지 못한다")
  func solarWithLeapMonth() {
    var fields = Self.validFields
    fields.dateIsLeapMonth = true
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("범위 밖 알림 시각은 읽지 못한다", arguments: [(24, 0), (12, 60), (-1, 0)])
  func invalidTime(hour: Int, minute: Int) {
    var fields = Self.validFields
    (fields.reminderHour, fields.reminderMinute) = (hour, minute)
    #expect(DDayRecordMapping.dDay(from: fields) == nil)
  }

  @Test("음력 표 밖 날짜도 그대로 읽는다 (쓰기가 만들 수 있는 값)", arguments: [(2051, 1, 1), (2026, 13, 1)])
  func lunarOutsideTable(year: Int, month: Int, day: Int) {
    var fields = Self.validFields
    fields.dateKind = "lunar"
    (fields.dateYear, fields.dateMonth, fields.dateDay) = (year, month, day)
    let dDay = DDayRecordMapping.dDay(from: fields)
    #expect(dDay?.schedule.date == Sample.lunar(year, month, day))
  }

  @Test("켜진 날짜는 reminderDaysBefore, 나머지 선택지는 reminderDisabledDaysBefore 에 오름차순으로 쓴다")
  func storedReminderFields() {
    let reminder = ReminderSettings(enabledDaysBefore: [30, 0], time: Sample.time(9, 0))
    let fields = DDayRecordMapping.fields(of: Self.dDay(Sample.draft(reminder: reminder)))
    #expect(fields.reminderDaysBefore == [0, 30])
    #expect(fields.reminderDisabledDaysBefore == [2, 7])
  }

  @Test("기념일 토글은 reminderEveryHundredDays·reminderAnniversaries 에 그대로 쓴다")
  func storedMilestoneFields() {
    let reminder = ReminderSettings(
      enabledDaysBefore: [0],
      time: Sample.time(9, 0),
      remindsEveryHundredDays: false,
      remindsAnniversaries: true
    )
    let fields = DDayRecordMapping.fields(of: Self.dDay(Sample.draft(reminder: reminder)))
    #expect(fields.reminderEveryHundredDays == false)
    #expect(fields.reminderAnniversaries == true)
    let defaults = DDayRecordMapping.fields(of: Self.dDay(Sample.draft(reminder: .default)))
    #expect(defaults.reminderEveryHundredDays && defaults.reminderAnniversaries)
  }

  @Test("선택지 밖 값(음수·1·14·366)과 꺼진 필드는 읽을 때 버리고 켜진 필드의 선택지만 켠다")
  func dropsUnknownDaysOnRead() {
    var fields = Self.validFields
    fields.reminderDaysBefore = [7, -3, 0, 7, 14, 366, 1]
    fields.reminderDisabledDaysBefore = [3, 30]
    #expect(DDayRecordMapping.dDay(from: fields)?.reminder.enabledDaysBefore == [0, 7])
  }

  @Test("켜진·꺼진 필드에 같은 날이 있으면 켜짐으로 읽는다")
  func overlappingDaysReadAsEnabled() {
    var fields = Self.validFields
    fields.reminderDaysBefore = [2]
    fields.reminderDisabledDaysBefore = [2, 7]
    #expect(DDayRecordMapping.dDay(from: fields)?.reminder.enabledDaysBefore == [2])
  }

  @Test("꺼진 날짜 필드가 빈 행(main 의 행)은 기본값과 같게 읽고 30일 전은 꺼짐이다")
  func legacyRowReadsThirtyDaysBeforeAsOff() {
    var fields = Self.validFields
    fields.reminderDaysBefore = [0, 2, 7]
    fields.reminderDisabledDaysBefore = []
    let reminder = DDayRecordMapping.dDay(from: fields)?.reminder
    #expect(reminder?.enabledDaysBefore == ReminderSettings.default.enabledDaysBefore)
    #expect(reminder?.enabledDaysBefore.contains(30) == false)
    #expect(reminder?.scheduledDaysBefore == [0, 2, 7])
  }

  @Test("꺼진 필드에만 있는 날짜는 꺼짐으로 읽는다")
  func disabledFieldAloneIsOff() {
    var fields = Self.validFields
    fields.reminderDaysBefore = []
    fields.reminderDisabledDaysBefore = [0, 2, 7, 30]
    #expect(DDayRecordMapping.dDay(from: fields)?.reminder.enabledDaysBefore.isEmpty == true)
  }

  @Test("사진 id 와 썸네일이 둘 다 있을 때만 사진이다")
  func photoMapping() {
    let id = Sample.id(3)
    let thumbnail = Data([1, 2, 3])

    #expect(DDayRecordMapping.photo(id: id, thumbnail: thumbnail) == DDayPhoto(id: id, thumbnail: thumbnail))
    #expect(DDayRecordMapping.photo(id: id, thumbnail: nil) == nil)
    #expect(DDayRecordMapping.photo(id: nil, thumbnail: thumbnail) == nil)
    #expect(DDayRecordMapping.photo(id: nil, thumbnail: nil) == nil)
  }

  @Test("넘긴 사진이 읽은 디데이의 photo 가 된다")
  func dDayWithPhoto() {
    let photo = DDayPhoto(id: Sample.id(3), thumbnail: Data([1]))
    let fields = DDayRecordMapping.fields(of: Self.dDay(Sample.draft()))

    #expect(DDayRecordMapping.dDay(from: fields, photo: photo)?.photo == photo)
    #expect(DDayRecordMapping.dDay(from: fields)?.photo == nil)
  }
}
