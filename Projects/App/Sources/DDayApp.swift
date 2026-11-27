import Core
import DDayEditorFeature
import DDayStoreImpl
import Foundation
import HomeFeature
import PhotoImpl
import SwiftUI

/// 조립 지점. Client Impl 을 만들어 Feature Model 에 주입하는 곳은 여기뿐이다.
@main
struct DDayApp: App {
  @State private var flow: AppFlow

  init() {
    // 저장소는 앱에 하나. 여기서는 열지 않고 첫 호출에서 연다 (열기 실패는 목록의 불러오기 오류로 보인다).
    // 홈과 상세·편집 화면이 이 store 를 같이 쓴다.
    let store = DDayStoreClientImpl()
    // 사진 처리는 상태가 없어 앱에 하나만 둔다. 선택 버튼(PhotosPicker)은 편집 화면 슬롯에 주입한다
    // (App 은 PhotosUI 를 import 하지 않는다).
    let photoClient = PhotoClientImpl()
    self._flow = State(initialValue: AppFlow(
      store: store,
      photoClient: photoClient,
      today: { CalendarDay(Date(), in: .autoupdatingCurrent) }
    ))
  }

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        HomeView(model: self.flow.homeModel)
          // 상세는 한 단계 push 뿐이라 path 대신 item 바인딩. 뒤로 가기·스와이프의 set(nil) 을 흐름에 알린다.
          .navigationDestination(item: Binding(
            get: { self.flow.detail },
            set: { session in
              if session == nil {
                self.flow.detailDismissed()
              }
            }
          )) { session in
            DDayDetailView(model: session.model)
          }
      }
      .sheet(item: Binding(
        get: { self.flow.editor },
        set: { session in
          if session == nil {
            self.flow.editorSheetDismissed()
          }
        }
      )) { session in
        DDayEditorView(model: session.model, photoPickerButton: PhotoPickerButton.init)
      }
    }
  }
}
