import Core
import DDayStoreImpl
import Foundation
import HomeFeature
import SwiftUI

/// 조립 지점. Client Impl 을 만들어 Feature Model 에 주입하는 곳은 여기뿐이다.
@main
struct DDayApp: App {
  @State private var homeModel: HomeModel

  init() {
    // 저장소는 앱에 하나. 여기서는 열지 않고 첫 호출에서 연다 (열기 실패는 목록의 불러오기 오류로 보인다).
    // 세션 3 의 추가·편집 모델도 이 store 를 받는다.
    let store = DDayStoreClientImpl()
    self._homeModel = State(initialValue: HomeModel(
      store: store,
      today: { CalendarDay(Date(), in: .autoupdatingCurrent) },
      onAddTapped: {}, // 세션 3 에서 추가 화면 연결
      onDDaySelected: { _ in } // 세션 3 에서 상세·편집 연결
    ))
  }

  var body: some Scene {
    WindowGroup {
      NavigationStack { HomeView(model: self.homeModel) }
    }
  }
}
