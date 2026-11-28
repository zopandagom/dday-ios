import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting
import Testing
@testable import ReminderFeature

/// 허용 상태의 예약·설정 열기·실패. 권한 분기는 ReminderModelAuthorizationTests, 겹침은 ReminderModelOverlapTests.
@MainActor
struct ReminderModelTests {
  let harness = ReminderHarness()

  @Test("설정 열기: 한 번 열고 권한·대기·회차 상태는 그대로")
  func notificationSettingsRequested() async {
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: fake)

    await model.notificationSettingsRequested()

    #expect(fake.openSettingsCount == 1)
    #expect(fake.replaceCount == 0)
    #expect(fake.requestAuthorizationCount == 0)
    #expect(model.authorization == nil)
    #expect(model.lastOutcome == nil)
    #expect(!model.isScheduling)
    #expect(self.harness.authorizationChanges.isEmpty)
  }

  @Test("설정 열기: 열지 못해도(false) 상태는 그대로")
  func notificationSettingsRequestedFailsSilently() async {
    let fake = LocalNotificationClientFake(opensSettings: false)
    let model = self.harness.makeModel(store: DDayStoreClientFake(), notifications: fake)
    await model.appLaunched()

    await model.notificationSettingsRequested()

    #expect(fake.openSettingsCount == 1)
    #expect(fake.replaceCount == 1)
    #expect(model.authorization == .authorized)
    #expect(model.lastOutcome == .scheduled(count: 0))
  }

  @Test("설정 열기: 회차가 도는 중에도 바로 열고 회차는 그대로 끝난다")
  func notificationSettingsRequestedWhileScheduling() async throws {
    let client = ControlledNotificationClient()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.appLaunched() }
    try await client.waitForPendingReplace()

    await model.notificationSettingsRequested()
    #expect(client.openSettingsCount == 1)
    #expect(model.isScheduling)

    try client.resumeReplace()
    await task.value
    #expect(!model.isScheduling)
    #expect(client.replaces == [ReminderSample.examRequests])
    #expect(model.lastOutcome == .scheduled(count: 3))
  }

  @Test("허용 + 앱 실행: 요청 없이 계획 결과를 예약")
  func appLaunchedSchedules() async {
    let fake = LocalNotificationClientFake(status: .authorized)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: fake)

    await model.appLaunched()

    #expect(model.authorization == .authorized)
    #expect(fake.requestAuthorizationCount == 0)
    #expect(fake.pending == ReminderSample.examRequests)
    #expect(model.scheduledRequests == ReminderSample.examRequests)
    #expect(model.lastOutcome == .scheduled(count: 3))
    #expect(!model.isScheduling)
    #expect(self.harness.authorizationChanges == [.authorized])
  }

  @Test("앱 복귀: 설정에서 거부 → 허용으로 바꾼 뒤 예약, 콜백은 바뀔 때마다")
  func sceneBecameActiveAfterAllowingInSettings() async {
    let fake = LocalNotificationClientFake(status: .denied)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: fake)
    await model.appLaunched()
    #expect(model.lastOutcome == .notAllowed)

    fake.setStatus(.authorized)
    await model.sceneBecameActive()

    #expect(model.authorization == .authorized)
    #expect(fake.pending == ReminderSample.examRequests)
    #expect(model.lastOutcome == .scheduled(count: 3))
    #expect(self.harness.authorizationChanges == [.denied, .authorized])
  }

  @Test("디데이 변경: 저장소의 새 내용으로 다시 예약 (지운 디데이 알림은 남지 않는다)")
  func dDaysChangedReschedules() async throws {
    let store = DDayStoreClientFake(dDays: [ReminderSample.exam])
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: store, notifications: fake)
    await model.appLaunched()

    try await store.delete(id: ReminderSample.exam.id)
    await model.dDaysChanged(requestAuthorizationIfNeeded: false)

    #expect(fake.replaceCount == 2)
    #expect(fake.pending.isEmpty)
    #expect(model.lastOutcome == .scheduled(count: 0))
  }

  @Test("알림 끈 디데이·지난 디데이만: 0개 예약")
  func nothingToSchedule() async {
    let disabled = ReminderSample.dDay(
      2,
      on: ReminderSample.day(2027, 3, 8),
      reminder: ReminderSample.reminder(isEnabled: false)
    )
    let past = ReminderSample.dDay(3, on: ReminderSample.day(2027, 2, 1))
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [disabled, past]), notifications: fake)

    await model.appLaunched()

    #expect(model.lastOutcome == .scheduled(count: 0))
    #expect(fake.pending.isEmpty)
    #expect(fake.replaceCount == 1)
    #expect(model.scheduledRequests.isEmpty)
  }

  @Test("60 한도: 디데이 30개 × 알림 날짜 4개 → 가까운 순 60개")
  func limitsToSixty() async {
    let dDays = (0 ..< 30).map { index in
      ReminderSample.dDay(
        100 + index,
        on: ReminderSample.day(2027, 5, 1).adding(days: index)!,
        reminder: ReminderSample.reminder([0, 2, 7, 30])
      )
    }
    let sources = dDays.map { dDay in
      ReminderSource(
        dDayID: dDay.id,
        schedule: dDay.schedule,
        daysBefore: dDay.reminder.scheduledDaysBefore,
        time: dDay.reminder.time,
        remindsEveryHundredDays: true,
        remindsAnniversaries: true
      )
    }
    let all = NotificationPlanner.plan(
      sources,
      today: ReminderSample.today,
      now: ReminderSample.time(8, 0),
      limit: 1000
    )
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: dDays), notifications: fake)

    await model.appLaunched()

    #expect(all.count == 120)
    #expect(fake.pending.count == 60)
    #expect(fake.pending.map(\.id) == all.prefix(60).map(\.identifier))
    #expect(model.lastOutcome == .scheduled(count: 60))
  }

  @Test("저장소 읽기 실패: 대기 요청을 건드리지 않고 .loadFailed")
  func loadFailedKeepsPending() async {
    let store = DDayStoreClientFake(dDays: [ReminderSample.exam])
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: store, notifications: fake)
    await model.appLaunched()

    store.failNextCall(with: .loadFailed)
    await model.sceneBecameActive()

    #expect(model.lastOutcome == .loadFailed)
    #expect(fake.replaceCount == 1)
    #expect(fake.pending == ReminderSample.examRequests)
    #expect(model.scheduledRequests == ReminderSample.examRequests)
    #expect(!model.isScheduling)
  }

  @Test("예약 실패: .scheduleFailed, 다음 복귀에서 다시 전체 교체")
  func scheduleFailedThenRecovers() async {
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: fake)
    fake.failNextReplace()

    await model.appLaunched()
    #expect(model.lastOutcome == .scheduleFailed)
    #expect(model.scheduledRequests == ReminderSample.examRequests)

    await model.sceneBecameActive()
    #expect(model.lastOutcome == .scheduled(count: 3))
    #expect(fake.replaceCount == 2)
    #expect(fake.pending == ReminderSample.examRequests)
  }

  @Test("주입한 지금·시간대: 오늘 9:00 알림은 8:59 면 포함, 9:00 이면 제외")
  func usesInjectedNowAndTimeZone() async {
    let today = ReminderSample.dDay(2, on: ReminderSample.today, reminder: ReminderSample.reminder([0]))
    let fake = LocalNotificationClientFake()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [today]), notifications: fake)

    self.harness.now = ReminderSample.date(2027, 3, 1, 8, 59)
    await model.appLaunched()
    #expect(model.lastOutcome == .scheduled(count: 1))

    self.harness.now = ReminderSample.date(2027, 3, 1, 9, 0)
    await model.sceneBecameActive()
    #expect(model.lastOutcome == .scheduled(count: 0))

    // 같은 순간(서울 8:59)이라도 UTC 로 보면 전날 23:59 라 당일 알림(3월 1일 9:00)이 미래다.
    self.harness.now = ReminderSample.date(2027, 3, 1, 8, 59)
    self.harness.timeZone = .gmt
    await model.sceneBecameActive()
    #expect(model.lastOutcome == .scheduled(count: 1))
  }
}
