import Core
import DDayStoreInterface
import Foundation
import LocalNotificationInterface
@testable import ReminderFeature

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다. 기준 시각은 서울 2027-03-01 08:00.
enum ReminderSample {
  static let seoul = TimeZone(identifier: "Asia/Seoul")!

  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
  }

  static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
    CalendarDay(year: year, month: month, day: day)!
  }

  static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
  }

  /// 서울 시각.
  static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = self.seoul
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
  }

  static let now = ReminderSample.date(2027, 3, 1, 8, 0)
  static var today: CalendarDay { self.day(2027, 3, 1) }

  static func reminder(
    _ daysBefore: Set<Int> = [0, 2, 7],
    isEnabled: Bool = true,
    time: TimeOfDay = .defaultReminderTime,
    hundredDays: Bool = true,
    anniversaries: Bool = true
  ) -> ReminderSettings {
    ReminderSettings(
      isEnabled: isEnabled,
      enabledDaysBefore: daysBefore,
      time: time,
      remindsEveryHundredDays: hundredDays,
      remindsAnniversaries: anniversaries
    )
  }

  static func dDay(
    _ number: Int,
    title: String? = nil,
    on day: CalendarDay,
    repeatRule: RepeatRule = .none,
    counting: CountingStyle = .dDay,
    reminder: ReminderSettings = .default
  ) -> DDay {
    let createdAt = Date(timeIntervalSince1970: TimeInterval(number * 10))
    return DDay(
      id: self.id(number),
      title: title ?? "디데이 \(number)",
      schedule: DDaySchedule(date: .solar(day), repeatRule: repeatRule, countingStyle: counting),
      reminder: reminder,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  /// 7일 뒤 시험 (D-day 방식, 기본 알림 당일·2일 전·7일 전 9:00). 기준 시각에서 요청 3개.
  static var exam: DDay {
    self.dDay(1, title: "시험", on: self.day(2027, 3, 8))
  }

  /// `exam` 의 기대 요청 (가까운 순). 본문은 실행 언어로 푼다.
  static var examRequests: [NotificationRequest] {
    let exam = self.exam
    return [(7, self.day(2027, 3, 1)), (2, self.day(2027, 3, 6)), (0, self.day(2027, 3, 8))].map { daysBefore, day in
      NotificationRequest(
        id: "dday.reminder.\(exam.id.uuidString).2027-03-08.\(daysBefore)",
        dDayID: exam.id,
        title: "시험",
        body: ReminderText.body(.target(daysBefore: daysBefore)),
        day: day,
        time: .defaultReminderTime
      )
    }
  }
}

/// `onAuthorizationChanged` 로 받은 값을 순서대로 남기고, 모델을 만든다.
@MainActor
final class ReminderHarness {
  var authorizationChanges: [NotificationAuthorization] = []
  /// 모델이 회차마다 읽는 지금 시각 (테스트가 바꿀 수 있다).
  var now = ReminderSample.now
  var timeZone = ReminderSample.seoul

  func makeModel(store: any DDayStoreClient, notifications: any LocalNotificationClient) -> ReminderModel {
    ReminderModel(
      store: store,
      notifications: notifications,
      now: { self.now },
      timeZone: { self.timeZone },
      onAuthorizationChanged: { self.authorizationChanges.append($0) }
    )
  }
}
