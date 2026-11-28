import DDayStoreTesting
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting
import Testing
@testable import ReminderFeature

/// 권한 분기: 미결정·거부·임시 허용, 요청 시점, 설정에서 바꾼 권한.
@MainActor
struct ReminderModelAuthorizationTests {
  let harness = ReminderHarness()

  func makeModel(_ fake: LocalNotificationClientFake) -> ReminderModel {
    self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: fake)
  }

  @Test("미결정 + 앱 실행: 요청하지 않고 대기 요청을 비운다")
  func notDeterminedAppLaunched() async {
    let fake = LocalNotificationClientFake(status: .notDetermined)
    let model = self.makeModel(fake)

    await model.appLaunched()

    #expect(fake.requestAuthorizationCount == 0)
    #expect(fake.replaceCount == 1)
    #expect(fake.pending.isEmpty)
    #expect(model.authorization == .notDetermined)
    #expect(model.lastOutcome == .notAllowed)
    #expect(model.scheduledRequests.isEmpty)
    #expect(self.harness.authorizationChanges == [.notDetermined])
  }

  @Test("미결정 + 앱 복귀: 요청하지 않는다")
  func notDeterminedSceneBecameActive() async {
    let fake = LocalNotificationClientFake(status: .notDetermined)
    let model = self.makeModel(fake)

    await model.sceneBecameActive()

    #expect(fake.requestAuthorizationCount == 0)
    #expect(model.lastOutcome == .notAllowed)
  }

  @Test("미결정 + 디데이 변경(요청 없음): 요청하지 않는다")
  func notDeterminedDDaysChangedWithoutRequest() async {
    let fake = LocalNotificationClientFake(status: .notDetermined)
    let model = self.makeModel(fake)

    await model.dDaysChanged(requestAuthorizationIfNeeded: false)

    #expect(fake.requestAuthorizationCount == 0)
    #expect(model.lastOutcome == .notAllowed)
  }

  @Test("미결정 + 디데이 변경(요청): 한 번 요청하고 허용이면 예약")
  func notDeterminedRequestAllowed() async {
    let fake = LocalNotificationClientFake(status: .notDetermined, statusAfterRequest: .authorized)
    let model = self.makeModel(fake)

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    #expect(fake.requestAuthorizationCount == 1)
    #expect(model.authorization == .authorized)
    #expect(fake.pending == ReminderSample.examRequests)
    #expect(model.lastOutcome == .scheduled(count: 3))
    #expect(self.harness.authorizationChanges == [.authorized])
  }

  @Test("미결정 + 디데이 변경(요청): 거부하면 비우고 오류 없이 .notAllowed, 콜백 .denied")
  func notDeterminedRequestDenied() async {
    let fake = LocalNotificationClientFake(status: .notDetermined, statusAfterRequest: .denied)
    let model = self.makeModel(fake)

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    #expect(fake.requestAuthorizationCount == 1)
    #expect(model.authorization == .denied)
    #expect(fake.pending.isEmpty)
    #expect(model.lastOutcome == .notAllowed)
    #expect(self.harness.authorizationChanges == [.denied])

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)
    #expect(fake.requestAuthorizationCount == 1)
  }

  @Test("거부 + 디데이 변경(요청): 정해진 상태라 요청하지 않는다")
  func deniedDoesNotRequest() async {
    let fake = LocalNotificationClientFake(status: .denied)
    let model = self.makeModel(fake)

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    #expect(fake.requestAuthorizationCount == 0)
    #expect(model.lastOutcome == .notAllowed)
    #expect(fake.pending.isEmpty)
  }

  @Test("임시 허용: 요청하지 않고 예약")
  func provisionalSchedules() async {
    let fake = LocalNotificationClientFake(status: .provisional)
    let model = self.makeModel(fake)

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    #expect(fake.requestAuthorizationCount == 0)
    #expect(model.authorization == .provisional)
    #expect(fake.pending == ReminderSample.examRequests)
    #expect(model.lastOutcome == .scheduled(count: 3))
  }

  @Test("허용 → 설정에서 거부 뒤 복귀: 대기 요청을 비우고 콜백 .denied")
  func deniedInSettingsClears() async {
    let fake = LocalNotificationClientFake(status: .authorized)
    let model = self.makeModel(fake)
    await model.appLaunched()
    #expect(fake.pending.count == 3)

    fake.setStatus(.denied)
    await model.sceneBecameActive()

    #expect(fake.pending.isEmpty)
    #expect(model.scheduledRequests.isEmpty)
    #expect(model.lastOutcome == .notAllowed)
    #expect(self.harness.authorizationChanges == [.authorized, .denied])
  }

  @Test("권한이 그대로면 콜백은 처음 한 번뿐")
  func callbackOnlyWhenChanged() async {
    let fake = LocalNotificationClientFake(status: .authorized)
    let model = self.makeModel(fake)

    await model.appLaunched()
    await model.sceneBecameActive()
    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    #expect(fake.replaceCount == 3)
    #expect(self.harness.authorizationChanges == [.authorized])
  }
}
