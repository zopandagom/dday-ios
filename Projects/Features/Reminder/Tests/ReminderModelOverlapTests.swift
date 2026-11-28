import DDayStoreTesting
import Foundation
import LocalNotificationInterface
import Testing
@testable import ReminderFeature

/// 회차 겹침: 교체·권한 프롬프트가 도는 중에 온 이벤트 (`ControlledNotificationClient` 로 멈춘다).
@MainActor
struct ReminderModelOverlapTests {
  let harness = ReminderHarness()

  @Test("교체 중 디데이 변경 두 번: 겹친 호출은 바로 돌아가고 교체는 총 2회, 두 번째는 새 저장소 내용")
  func changesDuringReplaceRerunOnce() async throws {
    let store = DDayStoreClientFake(dDays: [ReminderSample.exam])
    let client = ControlledNotificationClient()
    let model = self.harness.makeModel(store: store, notifications: client)
    let task = Task { await model.appLaunched() }
    try await client.waitForPendingReplace()

    try await store.delete(id: ReminderSample.exam.id)
    await model.dDaysChanged(requestAuthorizationIfNeeded: false)
    await model.dDaysChanged(requestAuthorizationIfNeeded: false)
    #expect(client.replaces.count == 1)
    #expect(model.isScheduling)

    try client.resumeReplace()
    try await client.waitForPendingReplace()
    #expect(client.replaces == [ReminderSample.examRequests, []])

    try client.resumeReplace()
    await task.value
    #expect(client.replaces.count == 2)
    #expect(!model.isScheduling)
    #expect(model.lastOutcome == .scheduled(count: 0))
    #expect(model.scheduledRequests.isEmpty)
  }

  @Test("프롬프트 중 디데이 변경(요청) 다시: 다음 회차는 정해진 상태라 요청은 총 1회")
  func requestDuringPromptAsksOnce() async throws {
    let client = ControlledNotificationClient(status: .notDetermined)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.dDaysChanged(requestAuthorizationIfNeeded: true) }
    try await client.waitForPendingAuthorization()

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    try client.resumeAuthorization(with: .authorized)
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    await task.value

    #expect(client.requestAuthorizationCount == 1)
    #expect(client.replaces == [ReminderSample.examRequests, ReminderSample.examRequests])
    #expect(model.lastOutcome == .scheduled(count: 3))
  }

  @Test("프롬프트 중 앱 복귀 → 허용: 교체 2회(같은 목록)·요청 1회·콜백 .authorized 1회")
  func sceneActiveDuringPromptAllowed() async throws {
    let client = ControlledNotificationClient(status: .notDetermined)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.dDaysChanged(requestAuthorizationIfNeeded: true) }
    try await client.waitForPendingAuthorization()

    await model.sceneBecameActive()
    #expect(client.calls == [.requestAuthorization])

    try client.resumeAuthorization(with: .authorized)
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    await task.value

    #expect(client.requestAuthorizationCount == 1)
    #expect(client.replaces == [ReminderSample.examRequests, ReminderSample.examRequests])
    #expect(self.harness.authorizationChanges == [.authorized])
  }

  @Test("프롬프트 중 앱 복귀 → 거부: 비우기 2회·요청 1회·콜백 .denied 1회")
  func sceneActiveDuringPromptDenied() async throws {
    let client = ControlledNotificationClient(status: .notDetermined)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.dDaysChanged(requestAuthorizationIfNeeded: true) }
    try await client.waitForPendingAuthorization()

    await model.sceneBecameActive()

    try client.resumeAuthorization(with: .denied)
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    await task.value

    #expect(client.requestAuthorizationCount == 1)
    #expect(client.replaces == [[], []])
    #expect(self.harness.authorizationChanges == [.denied])
    #expect(model.lastOutcome == .notAllowed)
  }

  @Test("교체 중 디데이 변경(요청), 이미 허용: 다음 회차에서도 요청 0회")
  func requestWhileAuthorizedDoesNotAsk() async throws {
    let client = ControlledNotificationClient(status: .authorized)
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.appLaunched() }
    try await client.waitForPendingReplace()

    await model.dDaysChanged(requestAuthorizationIfNeeded: true)

    try client.resumeReplace()
    try await client.waitForPendingReplace()
    try client.resumeReplace()
    await task.value

    #expect(client.requestAuthorizationCount == 0)
    #expect(client.replaces.count == 2)
  }

  @Test("교체 실패 뒤 한 번 더 회차는 새로 교체한다")
  func failedReplaceThenRerun() async throws {
    let client = ControlledNotificationClient()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.appLaunched() }
    try await client.waitForPendingReplace()

    await model.sceneBecameActive()
    try client.resumeReplace(fails: true)
    try await client.waitForPendingReplace()
    #expect(model.lastOutcome == .scheduleFailed)

    try client.resumeReplace()
    await task.value
    #expect(model.lastOutcome == .scheduled(count: 3))
  }

  @Test("회차 중 Task 취소: 취소를 보지 않고 교체를 끝까지 한다")
  func cancellationIsIgnored() async throws {
    let client = ControlledNotificationClient()
    let model = self.harness.makeModel(store: DDayStoreClientFake(dDays: [ReminderSample.exam]), notifications: client)
    let task = Task { await model.appLaunched() }
    try await client.waitForPendingReplace()

    task.cancel()
    try client.resumeReplace()
    await task.value

    #expect(client.replaces == [ReminderSample.examRequests])
    #expect(model.lastOutcome == .scheduled(count: 3))
    #expect(model.scheduledRequests == ReminderSample.examRequests)
    #expect(!model.isScheduling)
  }
}
