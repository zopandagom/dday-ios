import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import HomeFeature
import SwiftUI

#Preview("정상") {
  @Previewable @State var model = ExampleScenario.normal.makeFlow(clock: ExampleClock()).homeModel
  NavigationStack { HomeView(model: model) }
}

#Preview("빈 목록") {
  @Previewable @State var model = ExampleScenario.empty.makeFlow(clock: ExampleClock()).homeModel
  NavigationStack { HomeView(model: model) }
}

#Preview("불러오기 오류") {
  @Previewable @State var model = ExampleScenario.loadFailed.makeFlow(clock: ExampleClock()).homeModel
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
  @Previewable @State var model = ExampleScenario.brokenThumbnail.makeFlow(clock: ExampleClock()).homeModel
  NavigationStack { HomeView(model: model) }
}

#Preview("상세 (사진 있음)") {
  @Previewable @State var model = DetailPreviewSamples.model(dDay: DetailPreviewSamples.withPhoto)
  NavigationStack { DDayDetailView(model: model) }
}

#Preview("상세 (사진 없음)") {
  @Previewable @State var model = DetailPreviewSamples.model(dDay: DetailPreviewSamples.withoutPhoto)
  NavigationStack { DDayDetailView(model: model) }
}

#Preview("상세 (압축본 읽기 실패)") {
  @Previewable @State var model = DetailPreviewSamples.model(dDay: DetailPreviewSamples.withPhoto) {
    PhotoReadFailingStore(base: $0)
  }
  NavigationStack { DDayDetailView(model: model) }
}

#Preview("상세 (느린 읽기)") {
  @Previewable @State var model = DetailPreviewSamples.model(dDay: DetailPreviewSamples.withPhoto) {
    SlowPhotoStore(base: $0, delay: .seconds(3))
  }
  NavigationStack { DDayDetailView(model: model) }
}

/// 상세 Preview 의 샘플. 저장소에는 그 디데이와 압축본을 꼭 넣는다
/// (빠지면 fetchPhoto 가 `.notFound` 라 "사진 있음" 이 실패 화면처럼 보인다). 래퍼 저장소도 같은 Fake 를 base 로 쓴다.
@MainActor
private enum DetailPreviewSamples {
  static let today = CalendarDay(Date(), in: .autoupdatingCurrent)

  /// 사진 있는 양력 D-day.
  static let withPhoto = DDay(
    id: UUID(),
    title: "제주 여행",
    schedule: DDaySchedule(date: .solar(today.adding(days: 3) ?? today)),
    reminder: .default,
    createdAt: Date(timeIntervalSince1970: 0),
    updatedAt: Date(timeIntervalSince1970: 0),
    photo: ExampleSamples.defaultPhotos[1]?.photo
  )

  /// 사진 없는 음력 매년 D-day (양력 줄·처음 날짜가 보인다).
  static let withoutPhoto = DDay(
    id: UUID(),
    title: "추석",
    schedule: DDaySchedule(date: .lunar(LunarDate(year: 2000, month: 8, day: 15)), repeatRule: .yearly),
    reminder: .default,
    createdAt: Date(timeIntervalSince1970: 0),
    updatedAt: Date(timeIntervalSince1970: 0)
  )

  static func model(
    dDay: DDay,
    wrap: (DDayStoreClientFake) -> any DDayStoreClient = { $0 }
  ) -> DDayDetailModel {
    let image = dDay.photo == nil ? nil : ExampleSamples.defaultPhotos[1]?.image
    let fake = DDayStoreClientFake(dDays: [dDay], photoImages: image.map { [dDay.id: $0] } ?? [:])
    return DDayDetailModel(dDay: dDay, store: wrap(fake), today: { Self.today }, onEditTapped: { _ in })
  }
}
