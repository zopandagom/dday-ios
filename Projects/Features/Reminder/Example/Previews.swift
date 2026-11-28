import SwiftUI

/// 시나리오 하나를 고른 화면. 나타날 때 `appLaunched`(`requestsAuthorization` 이면 디데이 변경(권한 요청))를 한 번 보낸다.
private struct ExamplePreviewHost: View {
  @State private var session: ExampleSession
  private let requestsAuthorization: Bool

  init(_ scenario: ExampleScenario, requestsAuthorization: Bool = false) {
    self._session = State(initialValue: ExampleSession(scenario: scenario))
    self.requestsAuthorization = requestsAuthorization
  }

  var body: some View {
    NavigationStack {
      List {
        ExampleSessionSections(session: self.session)
      }
      .navigationTitle(self.session.scenario.title)
    }
    .task {
      if self.requestsAuthorization {
        await self.session.model.dDaysChanged(requestAuthorizationIfNeeded: true)
      } else {
        await self.session.model.appLaunched()
      }
    }
  }
}

#Preview("허용 목록") {
  ExamplePreviewHost(.allowed)
}

#Preview("거부 빈 목록") {
  ExamplePreviewHost(.denied)
}

#Preview("미결정 → 요청 전") {
  ExamplePreviewHost(.notDeterminedThenAllow)
}

#Preview("미결정 → 요청 뒤 허용") {
  ExamplePreviewHost(.notDeterminedThenAllow, requestsAuthorization: true)
}

#Preview("예약 실패") {
  ExamplePreviewHost(.scheduleFailed)
}
