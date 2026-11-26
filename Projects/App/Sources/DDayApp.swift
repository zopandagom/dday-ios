import Core
import DDayEditorFeature
import DDayStoreImpl
import Foundation
import HomeFeature
import SwiftUI

/// 조립 지점. Client Impl 을 만들어 Feature Model 에 주입하는 곳은 여기뿐이다.
@main
struct DDayApp: App {
  @State private var flow: AppFlow

  init() {
    // 저장소는 앱에 하나. 여기서는 열지 않고 첫 호출에서 연다 (열기 실패는 목록의 불러오기 오류로 보인다).
    // 홈과 편집 화면이 이 store 를 같이 쓴다.
    let store = DDayStoreClientImpl()
    self._flow = State(initialValue: AppFlow(
      store: store,
      today: { CalendarDay(Date(), in: .autoupdatingCurrent) }
    ))
  }

  var body: some Scene {
    WindowGroup {
      NavigationStack { HomeView(model: self.flow.homeModel) }
        .sheet(item: Binding(
          get: { self.flow.editor },
          set: { session in
            if session == nil {
              self.flow.editorSheetDismissed()
            }
          }
        )) { session in
          DDayEditorView(model: session.model)
        }
    }
  }
}
