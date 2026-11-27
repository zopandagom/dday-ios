import Core
import DDayStoreInterface
import Foundation
import HomeFeature
import SwiftUI

#Preview("정상") {
  @Previewable @State var model = ExampleScenario.normal.makeModel(clock: ExampleClock())
  NavigationStack { HomeView(model: model) }
}

#Preview("빈 목록") {
  @Previewable @State var model = ExampleScenario.empty.makeModel(clock: ExampleClock())
  NavigationStack { HomeView(model: model) }
}

#Preview("불러오기 오류") {
  @Previewable @State var model = ExampleScenario.loadFailed.makeModel(clock: ExampleClock())
  NavigationStack { HomeView(model: model) }
}

#Preview("로딩") {
  @Previewable @State var model = HomeModel(
    store: NeverEndingStore(),
    today: { CalendarDay(Date(), in: .autoupdatingCurrent) },
    onAddTapped: {},
    onDDaySelected: { _ in }
  )
  NavigationStack { HomeView(model: model) }
}

#Preview("카드 (사진 있음·없음)") {
  let today = CalendarDay(Date(), in: .autoupdatingCurrent)
  List {
    ForEach(ExampleSamples.dDays(today: today)) { dDay in
      DDayCardView(item: HomeItem(dDay: dDay, status: DDayStatus(schedule: dDay.schedule, today: today)))
    }
  }
}

#Preview("손상된 썸네일") {
  @Previewable @State var model = ExampleScenario.brokenThumbnail.makeModel(clock: ExampleClock())
  NavigationStack { HomeView(model: model) }
}
