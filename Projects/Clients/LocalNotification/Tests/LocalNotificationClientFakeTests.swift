import Core
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting
import Testing

struct LocalNotificationClientFakeTests {
  private func requests(_ count: Int) -> [NotificationRequest] {
    let day = CalendarDay(year: 2027, month: 3, day: 14) ?? CalendarDay(Date(timeIntervalSince1970: 0), in: .gmt)
    return (0 ..< count).map { index in
      NotificationRequest(
        id: "r\(index)",
        dDayID: UUID(uuidString: "00000000-0000-0000-0000-00000000000A") ?? UUID(),
        title: "t\(index)",
        body: "b\(index)",
        day: day,
        time: .defaultReminderTime
      )
    }
  }

  @Test("미결정에서 요청하면 statusAfterRequest 로 바뀐다", arguments: [NotificationAuthorization.authorized, .denied])
  func requestFromNotDetermined(after: NotificationAuthorization) async {
    let fake = LocalNotificationClientFake(status: .notDetermined, statusAfterRequest: after)
    #expect(await fake.authorizationStatus() == .notDetermined)
    #expect(await fake.requestAuthorization() == after)
    #expect(await fake.authorizationStatus() == after)
    #expect(fake.requestAuthorizationCount == 1)
  }

  @Test("정해진 상태에서 요청하면 그대로", arguments: [NotificationAuthorization.denied, .provisional, .authorized])
  func requestFromDetermined(status: NotificationAuthorization) async {
    let fake = LocalNotificationClientFake(status: status, statusAfterRequest: .notDetermined)
    #expect(await fake.requestAuthorization() == status)
    #expect(fake.status == status)
    #expect(fake.requestAuthorizationCount == 1)
  }

  @Test("허용이면 지우고 새로 넣는다, 앞 64개까지")
  func replaceAllowed() async throws {
    let fake = LocalNotificationClientFake()
    try await fake.replacePending(self.requests(3))
    try await fake.replacePending(self.requests(70))
    #expect(fake.pending.count == LocalNotificationLimits.maximumPendingCount)
    #expect(fake.pending == Array(self.requests(70).prefix(64)))
    try await fake.replacePending([])
    #expect(fake.pending.isEmpty)
    #expect(fake.replaceCount == 3)
  }

  @Test("임시 허용도 예약한다")
  func replaceProvisional() async throws {
    let fake = LocalNotificationClientFake(status: .provisional)
    try await fake.replacePending(self.requests(2))
    #expect(fake.pending.map(\.id) == ["r0", "r1"])
  }

  @Test("허용이 아니면 비우기만 하고, 넣을 요청이 있으면 scheduleFailed", arguments: [NotificationAuthorization.notDetermined, .denied])
  func replaceNotAllowed(status: NotificationAuthorization) async throws {
    let fake = LocalNotificationClientFake()
    try await fake.replacePending(self.requests(2))
    fake.setStatus(status)
    await #expect(throws: LocalNotificationError.scheduleFailed) { try await fake.replacePending(self.requests(2)) }
    #expect(fake.pending.isEmpty)
    try await fake.replacePending([])
    #expect(fake.pending.isEmpty)
    #expect(fake.replaceCount == 3)
  }

  @Test("failNextReplace 는 다음 한 번만: 넣기는 하고 실패를 던진다")
  func failNextReplaceOnce() async throws {
    let fake = LocalNotificationClientFake()
    fake.failNextReplace()
    await #expect(throws: LocalNotificationError.scheduleFailed) { try await fake.replacePending(self.requests(2)) }
    #expect(fake.pending.map(\.id) == ["r0", "r1"])
    try await fake.replacePending(self.requests(1))
    #expect(fake.pending.map(\.id) == ["r0"])
  }

  @Test("setStatus 는 대기 요청을 건드리지 않는다")
  func setStatusKeepsPending() async throws {
    let fake = LocalNotificationClientFake()
    try await fake.replacePending(self.requests(2))
    fake.setStatus(.denied)
    #expect(await fake.authorizationStatus() == .denied)
    #expect(fake.pending.count == 2)
  }

  @Test("openSettings 는 횟수를 세고 init 값을 돌려주며 상태는 그대로", arguments: [true, false])
  func openSettings(opens: Bool) async {
    let fake = LocalNotificationClientFake(status: .denied, opensSettings: opens)
    #expect(await fake.openSettings() == opens)
    #expect(await fake.openSettings() == opens)
    #expect(fake.openSettingsCount == 2)
    #expect(fake.status == .denied)
    #expect(fake.requestAuthorizationCount == 0)
    #expect(fake.replaceCount == 0)
  }
}
