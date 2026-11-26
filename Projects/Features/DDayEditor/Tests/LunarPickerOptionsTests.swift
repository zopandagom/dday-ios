import Core
import Testing
@testable import DDayEditorFeature

struct LunarPickerOptionsTests {
  struct LastDayCase: Sendable, CustomTestStringConvertible {
    let year: Int
    let month: Int
    let isLeap: Bool
    let expected: Int?

    var testDescription: String {
      "\(self.year)-\(self.month)\(self.isLeap ? " 윤" : "") → \(self.expected.map(String.init) ?? "nil")"
    }
  }

  @Test("연 선택지는 표 범위 1900~2050")
  func yearsCoverTable() {
    let choices = LunarPickerOptions.choices(for: EditorSample.lunar(2026, 1, 1))

    #expect(choices.years == 1900 ... 2050)
  }

  @Test("2050년은 11월까지만 고를 수 있다")
  func monthsIn2050StopAtNovember() {
    #expect(LunarPickerOptions.months(in: 2050) == Array(1 ... 11))
  }

  @Test("보통 해는 1~12월", arguments: [1900, 2025, 2026, 2049])
  func monthsInOrdinaryYear(year: Int) {
    #expect(LunarPickerOptions.months(in: year) == Array(1 ... 12))
  }

  @Test("고를 수 있는 윤달", arguments: [(2025, 6), (2026, nil), (2050, 3), (1900, 8), (2033, 11)] as [(Int, Int?)])
  func leapMonths(year: Int, expected: Int?) {
    #expect(LunarPickerOptions.leapMonth(in: year) == expected)
  }

  @Test(
    "고를 수 있는 마지막 날",
    arguments: [
      LastDayCase(year: 2050, month: 11, isLeap: false, expected: 18),
      LastDayCase(year: 2050, month: 12, isLeap: false, expected: nil),
      LastDayCase(year: 2025, month: 6, isLeap: true, expected: 29),
      LastDayCase(year: 2025, month: 6, isLeap: false, expected: 30),
      LastDayCase(year: 2027, month: 1, isLeap: false, expected: 29),
      LastDayCase(year: 2026, month: 1, isLeap: false, expected: 30),
      LastDayCase(year: 2026, month: 6, isLeap: true, expected: nil),
      LastDayCase(year: 2050, month: 3, isLeap: true, expected: 30),
    ]
  )
  func lastDays(_ testCase: LastDayCase) {
    let lastDay = LunarPickerOptions.lastDay(year: testCase.year, month: testCase.month, isLeapMonth: testCase.isLeap)
    #expect(lastDay == testCase.expected)
  }

  @Test(
    "고를 수 있는 값으로 맞추기",
    arguments: [
      (EditorSample.lunar(2026, 6, 15, leap: true), EditorSample.lunar(2026, 6, 15)),
      (EditorSample.lunar(2050, 12, 29), EditorSample.lunar(2050, 11, 18)),
      (EditorSample.lunar(2027, 1, 30), EditorSample.lunar(2027, 1, 29)),
      (EditorSample.lunar(2025, 6, 30, leap: true), EditorSample.lunar(2025, 6, 29, leap: true)),
      (EditorSample.lunar(2025, 7, 29, leap: true), EditorSample.lunar(2025, 7, 29)),
      (EditorSample.lunar(2050, 11, 30), EditorSample.lunar(2050, 11, 18)),
      (EditorSample.lunar(2026, 6, 1, leap: true), EditorSample.lunar(2026, 6, 1)),
      (EditorSample.lunar(2050, 11, 19), EditorSample.lunar(2050, 11, 18)),
      (EditorSample.lunar(2051, 1, 1), EditorSample.lunar(2050, 1, 1)),
      (EditorSample.lunar(1899, 12, 1), EditorSample.lunar(1900, 12, 1)),
      (EditorSample.lunar(2026, 0, 5), EditorSample.lunar(2026, 1, 5)),
      (EditorSample.lunar(2026, 13, 5), EditorSample.lunar(2026, 12, 5)),
      (EditorSample.lunar(2026, 3, 0), EditorSample.lunar(2026, 3, 1)),
      (EditorSample.lunar(2026, 10, 18), EditorSample.lunar(2026, 10, 18)),
    ]
  )
  func normalizedExamples(input: LunarDate, expected: LunarDate) {
    let result = LunarPickerOptions.normalized(
      year: input.year,
      month: input.month,
      isLeapMonth: input.isLeapMonth,
      day: input.day
    )

    #expect(result == expected)
  }

  @Test("선택지에 든 값은 모두 변환되고, 선택지 밖의 값은 변환되지 않는다")
  func everyChoiceConvertsAndNothingElseDoes() {
    var mismatches: [LunarDate] = []
    for year in 1900 ... 2050 {
      let base = LunarPickerOptions.choices(for: LunarPickerOptions.normalized(
        year: year,
        month: 1,
        isLeapMonth: false,
        day: 1
      ))
      #expect(base.years.contains(year))
      for month in 1 ... 12 {
        for isLeap in [false, true] {
          let isMonthListed = isLeap ? base.leapMonth == month : base.months.contains(month)
          let days = isMonthListed
            ? LunarPickerOptions.choices(for: LunarDate(year: year, month: month, day: 1, isLeapMonth: isLeap)).days
            : nil
          for day in 1 ... 30 {
            let lunar = LunarDate(year: year, month: month, day: day, isLeapMonth: isLeap)
            let isListed = days?.contains(day) ?? false
            if isListed != (KoreanLunarCalendar.solarDay(from: lunar) != nil) {
              mismatches.append(lunar)
            }
          }
        }
      }
    }

    #expect(mismatches.isEmpty)
  }

  @Test("맞춘 값은 늘 고를 수 있다")
  func normalizedAlwaysSelectable() {
    var failures: [LunarDate] = []
    for year in 1899 ... 2051 {
      for month in 0 ... 13 {
        for isLeap in [false, true] {
          for day in 0 ... 31 {
            let result = LunarPickerOptions.normalized(year: year, month: month, isLeapMonth: isLeap, day: day)
            if KoreanLunarCalendar.solarDay(from: result) == nil {
              failures.append(result)
            }
          }
        }
      }
    }

    #expect(failures.isEmpty)
  }
}
