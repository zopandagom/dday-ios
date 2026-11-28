import Core
import Foundation
import LocalNotificationInterface
import Testing
import UserNotifications
@testable import LocalNotificationImpl

struct NotificationRequestMappingTests {
  private let dDayID = UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID()

  private func sample() throws -> NotificationRequest {
    try NotificationRequest(
      id: "dday.reminder.00000000-0000-0000-0000-00000000000A.2027-03-14.7",
      dDayID: self.dDayID,
      title: "시험",
      body: "7일 남았어요",
      day: #require(CalendarDay(year: 2027, month: 3, day: 7)),
      time: #require(TimeOfDay(hour: 9, minute: 5))
    )
  }

  @Test("권한 상태: 그대로 옮기고 ephemeral 은 허용으로")
  func authorization() {
    #expect(NotificationRequestMapping.authorization(from: .notDetermined) == .notDetermined)
    #expect(NotificationRequestMapping.authorization(from: .denied) == .denied)
    #expect(NotificationRequestMapping.authorization(from: .authorized) == .authorized)
    #expect(NotificationRequestMapping.authorization(from: .provisional) == .provisional)
    #expect(NotificationRequestMapping.authorization(from: .ephemeral) == .authorized)
  }

  @Test("예약할 수 있는 상태는 허용·임시 허용뿐")
  func allowsScheduling() {
    #expect(NotificationAuthorization.authorized.allowsScheduling)
    #expect(NotificationAuthorization.provisional.allowsScheduling)
    #expect(!NotificationAuthorization.notDetermined.allowsScheduling)
    #expect(!NotificationAuthorization.denied.allowsScheduling)
  }

  @Test("트리거 날짜는 그레고리력 연·월·일·시·분이고 시간대가 없다")
  func dateComponents() throws {
    let request = try self.sample()
    let components = NotificationRequestMapping.dateComponents(day: request.day, time: request.time)
    #expect(components.calendar?.identifier == .gregorian)
    #expect(components.timeZone == nil)
    #expect(components.year == 2027)
    #expect(components.month == 3)
    #expect(components.day == 7)
    #expect(components.hour == 9)
    #expect(components.minute == 5)
    #expect(components.second == nil)
  }

  @Test("요청: 식별자·제목·본문·소리·userInfo 디데이 id, 한 번만 울리는 달력 트리거")
  func request() throws {
    let request = try self.sample()
    let mapped = NotificationRequestMapping.request(for: request)
    #expect(mapped.identifier == request.id)
    #expect(mapped.content.title == "시험")
    #expect(mapped.content.body == "7일 남았어요")
    #expect(mapped.content.sound != nil)
    #expect(mapped.content.userInfo as? [String: String] == ["dDayID": self.dDayID.uuidString])
    let trigger = try #require(mapped.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == false)
    #expect(trigger.dateComponents.year == 2027)
    #expect(trigger.dateComponents.month == 3)
    #expect(trigger.dateComponents.day == 7)
    #expect(trigger.dateComponents.hour == 9)
    #expect(trigger.dateComponents.minute == 5)
    #expect(trigger.dateComponents.timeZone == nil)
    #expect(trigger.dateComponents.calendar?.identifier == .gregorian)
  }
}
