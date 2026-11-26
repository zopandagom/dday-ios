import Core
import Foundation
import Testing
@testable import DDayEditorFeature

struct EditorDateConversionTests {
  static let timeZones = ["Asia/Seoul", "America/Los_Angeles", "Pacific/Kiritimati", "America/Sao_Paulo"]
    .compactMap(TimeZone.init(identifier:))

  @Test(
    "날짜는 어느 시간대에서도 같은 날로 왕복한다 (자정이 없는 서머타임 전환일 포함)",
    arguments: EditorDateConversionTests.timeZones,
    [EditorSample.day(1900, 1, 31), EditorSample.day(2018, 11, 4), EditorSample.day(2050, 12, 31)]
  )
  func calendarDayRoundTrip(timeZone: TimeZone, day: CalendarDay) {
    let date = EditorDateConversion.date(from: day, in: timeZone)

    #expect(EditorDateConversion.calendarDay(from: date, in: timeZone) == day)
  }

  @Test(
    "시각은 어느 시간대에서도 같은 시·분으로 왕복한다",
    arguments: EditorDateConversionTests.timeZones,
    [EditorSample.time(0, 0), EditorSample.time(9, 0), EditorSample.time(23, 59)]
  )
  func timeOfDayRoundTrip(timeZone: TimeZone, time: TimeOfDay) {
    let date = EditorDateConversion.date(from: time, in: timeZone)

    #expect(EditorDateConversion.timeOfDay(from: date, in: timeZone) == time)
  }

  @Test("시간대 목록을 모두 만들었다")
  func timeZonesExist() {
    #expect(Self.timeZones.count == 4)
  }
}
