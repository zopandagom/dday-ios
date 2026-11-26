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
      daysBefore: [1, 3],
      time: Sample.time(20, 30)
    ))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(isEnabled: true, daysBefore: [], time: Sample.time(9, 0)))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(daysBefore: [0], time: Sample.time(23, 59)))),
    Self.dDay(Sample.draft(reminder: ReminderSettings(daysBefore: [0, 30], time: Sample.time(0, 0)))),
    Self.dDay(Sample.draft(reminder: .default)),
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

  @Test("며칠 전 목록의 음수·중복은 읽을 때 정규화된다")
  func normalizesDaysBeforeOnRead() {
    var fields = Self.validFields
    fields.reminderDaysBefore = [7, -3, 0, 7, 2]
    #expect(DDayRecordMapping.dDay(from: fields)?.reminder.daysBefore == [0, 2, 7])
  }
}
