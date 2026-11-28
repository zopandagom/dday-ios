import Core
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting
import Observation
import ReminderFeature
import SwiftUI

/// App 없이 알림 예약 흐름만 돌려 보는 데모 앱. 시나리오(권한·실패)를 고르면 Fake 로 `ReminderModel` 을 만들고,
/// App 의 시점(앱 실행·복귀·디데이 변경)을 버튼으로 보내 상태와 예약 목록(`scheduledRequests`)을 보인다.
/// 영어 문구는 `-AppleLanguages "(en)"` 로 실행해 본다.
@main
struct ReminderFeatureExampleApp: App {
  @State private var session: ExampleSession?

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          Section("시나리오") {
            ForEach(ExampleScenario.allCases) { scenario in
              Button {
                self.session = ExampleSession(scenario: scenario)
              } label: {
                HStack {
                  Text(scenario.title)
                  Spacer()
                  if self.session?.scenario == scenario {
                    Image(systemName: "checkmark")
                  }
                }
              }
            }
          }
          if let session = self.session {
            ExampleSessionSections(session: session)
          }
        }
        .navigationTitle("Reminder 예제")
      }
    }
  }
}

/// 고른 시나리오의 모델과 Fake. Example 이 소유한다.
@MainActor
@Observable
final class ExampleSession {
  let scenario: ExampleScenario
  let model: ReminderModel
  let fake: LocalNotificationClientFake
  private(set) var authorizationChanges: [NotificationAuthorization] = []

  init(scenario: ExampleScenario) {
    let setup = scenario.makeSetup(today: CalendarDay(Date(), in: .autoupdatingCurrent))
    let changes = AuthorizationChangeBox()
    self.scenario = scenario
    self.fake = setup.fake
    self.model = ReminderModel(
      store: setup.store,
      notifications: setup.notifications,
      now: { Date() },
      timeZone: { .autoupdatingCurrent },
      onAuthorizationChanged: { changes.session?.authorizationChanges.append($0) }
    )
    changes.session = self
  }

  /// 설정 앱에서 허용으로 바꾸고 돌아온 것처럼.
  func allowInSettings() async {
    self.fake.setStatus(.authorized)
    await self.model.sceneBecameActive()
  }
}

/// init 안에서 self 를 콜백에 넘기기 위한 약한 상자 (App 의 `flowReference` 와 같은 방식).
@MainActor
private final class AuthorizationChangeBox {
  weak var session: ExampleSession?
}

/// 이벤트 버튼·상태 줄·예약 목록.
struct ExampleSessionSections: View {
  let session: ExampleSession

  private var model: ReminderModel {
    self.session.model
  }

  var body: some View {
    Section("이벤트") {
      Button("앱 실행") { Task { await self.model.appLaunched() } }
      Button("앱 복귀") { Task { await self.model.sceneBecameActive() } }
      Button("디데이 변경 (권한 요청)") { Task { await self.model.dDaysChanged(requestAuthorizationIfNeeded: true) } }
      Button("디데이 변경") { Task { await self.model.dDaysChanged(requestAuthorizationIfNeeded: false) } }
      Button("설정에서 허용으로 바꾸기") { Task { await self.session.allowInSettings() } }
      Button("설정 열기") { Task { await self.model.notificationSettingsRequested() } }
    }
    Section("상태") {
      LabeledContent("권한", value: self.model.authorization.map { String(describing: $0) } ?? "-")
      LabeledContent("회차 도는 중", value: self.model.isScheduling ? "예" : "아니오")
      LabeledContent("마지막 결과", value: self.model.lastOutcome.map { String(describing: $0) } ?? "-")
      LabeledContent("권한 요청 횟수", value: String(self.session.fake.requestAuthorizationCount))
      LabeledContent("대기 요청 수 (Fake)", value: String(self.session.fake.pending.count))
      LabeledContent("설정 열기 횟수", value: String(self.session.fake.openSettingsCount))
      LabeledContent(
        "권한 변경 콜백",
        value: self.session.authorizationChanges.map { String(describing: $0) }.joined(separator: ", ")
      )
    }
    Section("예약 목록 (\(String(self.model.scheduledRequests.count)))") {
      ReminderRequestListView(requests: self.model.scheduledRequests)
    }
  }
}
