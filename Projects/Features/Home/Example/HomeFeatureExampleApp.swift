import HomeFeature
import SwiftUI

/// App 없이 홈 목록만 띄우는 데모 앱. 시나리오(정상·빈 목록·불러오기 오류·삭제 실패·손상된 썸네일)를 골라 Fake 로 확인한다.
/// 정상 시나리오는 사진 있는 카드와 없는 카드(기본 배경)가 섞여 있다.
@main
struct HomeFeatureExampleApp: App {
  @State private var clock = ExampleClock()
  @State private var session: ExampleSession?

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List(ExampleScenario.allCases) { scenario in
          Button(scenario.title) {
            self.session = ExampleSession(scenario: scenario, model: scenario.makeModel(clock: self.clock))
          }
        }
        .navigationTitle("Home 예제")
        .navigationDestination(item: self.$session) { session in
          ExampleScreen(model: session.model, clock: self.clock)
        }
      }
    }
  }
}

/// 고른 시나리오와 그 모델. 모델은 App 의 `@State` 가 소유한다.
struct ExampleSession: Identifiable, Hashable {
  let id = UUID()
  let scenario: ExampleScenario
  let model: HomeModel

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

/// 홈 화면 + "하루 뒤로" 버튼 (재정렬 수동 확인용).
struct ExampleScreen: View {
  let model: HomeModel
  let clock: ExampleClock

  var body: some View {
    HomeView(model: self.model)
      .safeAreaInset(edge: .bottom) {
        Button("하루 뒤로") {
          self.clock.advanceOneDay()
          self.model.calendarDayChanged()
        }
        .buttonStyle(.borderedProminent)
        .padding()
      }
  }
}
