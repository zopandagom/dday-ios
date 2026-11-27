import HomeFeature
import SwiftUI

/// App 없이 홈 목록과 디데이 상세만 띄우는 데모 앱. 시나리오(정상(기본 폴더만)·직접 만든 폴더 여럿·폴더 없음·폴더 읽기 실패·
/// 빈 목록·불러오기 오류·삭제 실패·손상된 썸네일·느린 압축본 읽기·압축본 읽기 실패·압축본 없음)를 골라 Fake 로 확인한다.
/// 정상 시나리오는 사진 있는 카드와 없는 카드(폴더 색 기본 배경, 미분류는 기본 배경)가 섞여 있고 위에 폴더 칩 줄이 있다.
/// 카드를 누르면 상세가 push 되고(`ExampleFlow`), 상세 [편집] 은 편집 화면 대신 흉내 확인창(사진 바꿔 저장·사진 지워 저장·
/// 폴더 바꿔 저장·제목 바꿔 저장·삭제)을 띄워 결과를 홈·상세에 넘긴다.
@main
struct HomeFeatureExampleApp: App {
  @State private var clock = ExampleClock()
  @State private var session: ExampleSession?

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List(ExampleScenario.allCases) { scenario in
          Button(scenario.title) {
            self.session = ExampleSession(scenario: scenario, flow: scenario.makeFlow(clock: self.clock))
          }
        }
        .navigationTitle("Home 예제")
        .navigationDestination(item: self.$session) { session in
          ExampleScreen(flow: session.flow, clock: self.clock)
        }
      }
    }
  }
}

/// 고른 시나리오와 그 흐름. 흐름은 App 의 `@State` 가 소유한다.
struct ExampleSession: Identifiable, Hashable {
  let id = UUID()
  let scenario: ExampleScenario
  let flow: ExampleFlow

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

/// 홈 화면 + "하루 뒤로" 버튼 (재정렬 수동 확인용) + 상세 push.
struct ExampleScreen: View {
  let flow: ExampleFlow
  let clock: ExampleClock

  var body: some View {
    HomeView(model: self.flow.homeModel)
      .safeAreaInset(edge: .bottom) {
        Button("하루 뒤로") {
          self.clock.advanceOneDay()
          self.flow.homeModel.calendarDayChanged()
        }
        .buttonStyle(.borderedProminent)
        .padding()
      }
      .navigationDestination(item: Binding(
        get: { self.flow.detail },
        set: { session in
          if session == nil {
            self.flow.detailDismissed()
          }
        }
      )) { session in
        ExampleDetailScreen(flow: self.flow, model: session.model)
      }
  }
}

/// 상세 화면 + 흉내 편집 확인창 (Example 전용 문구라 String Catalog 밖).
struct ExampleDetailScreen: View {
  let flow: ExampleFlow
  let model: DDayDetailModel

  var body: some View {
    DDayDetailView(model: self.model)
      .confirmationDialog(
        "흉내 편집",
        isPresented: Binding(
          get: { self.flow.editingDDay != nil },
          set: { isPresented in
            if !isPresented {
              self.flow.editDialogDismissed()
            }
          }
        ),
        titleVisibility: .visible,
        presenting: self.flow.editingDDay
      ) { dDay in
        Button("사진 바꿔 저장") { self.flow.replacePhotoTapped(dDay) }
        Button("사진 지워 저장") { self.flow.removePhotoTapped(dDay) }
        Button("폴더 바꿔 저장") { self.flow.changeFolderTapped(dDay) }
        Button("제목 바꿔 저장") { self.flow.renameTapped(dDay) }
        Button("삭제", role: .destructive) { self.flow.deleteTapped(dDay) }
        Button("취소", role: .cancel) {}
      } message: { dDay in
        Text(verbatim: "\(dDay.title) 를 편집 화면 대신 바로 저장소에 저장한다")
      }
  }
}
