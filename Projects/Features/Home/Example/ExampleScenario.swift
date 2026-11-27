import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import HomeFeature

/// Example 앱에서 고르는 화면 상태.
enum ExampleScenario: String, CaseIterable, Identifiable {
  case normal
  case empty
  case loadFailed
  case deleteFailed
  case brokenThumbnail
  case slowPhotoRead
  case photoReadFailed
  case missingLargePhoto

  var id: Self { self }

  var title: String {
    switch self {
    case .normal: "정상"
    case .empty: "빈 목록"
    case .loadFailed: "불러오기 오류 (다시 시도·앱 복귀로 회복)"
    case .deleteFailed: "삭제 실패"
    case .brokenThumbnail: "손상된 썸네일 (기본 배경으로 보임)"
    case .slowPhotoRead: "느린 압축본 읽기 (3초)"
    case .photoReadFailed: "압축본 읽기 실패 (상세에 썸네일)"
    case .missingLargePhoto: "압축본 없음 (상세에 썸네일)"
    }
  }

  /// 이 시나리오의 흐름(홈·상세 모델). `today` 는 넘긴 `clock` 인스턴스에서 구한다.
  @MainActor
  func makeFlow(clock: ExampleClock) -> ExampleFlow {
    let samples = ExampleSamples.samples(today: clock.today())
    let store: any DDayStoreClient
    switch self {
    case .normal:
      store = DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages)
    case .empty:
      store = DDayStoreClientFake()
    case .loadFailed:
      // 저장소 열기 실패도 이렇게(첫 불러오기의 .loadFailed) 보인다.
      let fake = DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages)
      fake.failNextCall(with: .loadFailed)
      store = fake
    case .deleteFailed:
      store = DeleteFailingStore(base: DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages))
    case .brokenThumbnail:
      let broken = ExampleSamples.samples(today: clock.today(), photos: [
        0: ExamplePhotos.broken,
        1: ExampleSamples.defaultPhotos[4] ?? ExamplePhotos.broken,
      ])
      store = DDayStoreClientFake(dDays: broken.dDays, photoImages: broken.photoImages)
    case .slowPhotoRead:
      store = SlowPhotoStore(
        base: DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages),
        delay: .seconds(3)
      )
    case .photoReadFailed:
      store = PhotoReadFailingStore(base: DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages))
    case .missingLargePhoto:
      // 사진은 있지만 압축본 행이 없다: fetchPhoto 가 nil.
      store = DDayStoreClientFake(dDays: samples.dDays)
    }
    return ExampleFlow(store: store, today: { clock.today() })
  }
}

/// 실제 오늘 기준 상대 날짜로 만든 샘플. 네 그룹(다가오는·세는 중·지난·계산 불가)이 모두 나온다.
/// 일부 카드에 직접 그린 사진(썸네일·압축본)을 붙인다 (나머지는 기본 배경).
enum ExampleSamples {
  /// 순서 번호 → 사진 (기본 샘플). 한 번만 그린다.
  static let defaultPhotos: [Int: ExamplePhotos.Sample] = [
    1: ExamplePhotos.sample(.init(1, 0.78, 0.66), .init(1, 0.56, 0.69)),
    4: ExamplePhotos.sample(.init(0.66, 0.9, 0.81), .init(0.79, 0.71, 1)),
    6: ExamplePhotos.sample(.init(1, 0.91, 0.64), .init(1, 0.78, 0.66)),
  ]

  /// 샘플 디데이와 그 압축본(디데이 id → JPEG, Fake 의 `photoImages`).
  static func samples(
    today: CalendarDay,
    photos: [Int: ExamplePhotos.Sample] = ExampleSamples.defaultPhotos
  ) -> (dDays: [DDay], photoImages: [UUID: Data]) {
    let dDays = self.dDays(today: today, photos: photos.mapValues(\.photo))
    var photoImages: [UUID: Data] = [:]
    for (index, dDay) in dDays.enumerated() {
      photoImages[dDay.id] = photos[index]?.image
    }
    return (dDays, photoImages)
  }

  static func dDays(
    today: CalendarDay,
    photos: [Int: DDayPhoto] = ExampleSamples.defaultPhotos.mapValues(\.photo)
  ) -> [DDay] {
    func solar(_ offset: Int) -> DDayDate {
      .solar(today.adding(days: offset) ?? today)
    }
    let birthday = CalendarDay(year: 2000, month: 3, day: 14).map(DDayDate.solar) ?? solar(30)
    let schedules: [(String, DDaySchedule)] = [
      ("기말고사", DDaySchedule(date: solar(0))),
      ("제주 여행", DDaySchedule(date: solar(3))),
      ("엄마 생일", DDaySchedule(date: birthday, repeatRule: .yearly)),
      ("추석", DDaySchedule(date: .lunar(LunarDate(year: 2000, month: 8, day: 15)), repeatRule: .yearly)),
      ("우리 만난 날", DDaySchedule(date: solar(-100), countingStyle: .dPlus)),
      ("새 다이어리", DDaySchedule(date: solar(0), countingStyle: .dPlus)),
      ("운동 시작", DDaySchedule(date: solar(-10), countingStyle: .dayOne)),
      ("방학", DDaySchedule(date: solar(5), countingStyle: .dayOne)),
      ("콘서트", DDaySchedule(date: solar(-7))),
      ("윤달 기념일", DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)))),
    ]
    return schedules.enumerated().map { index, entry in
      let createdAt = Date(timeIntervalSince1970: TimeInterval(index))
      return DDay(
        id: UUID(),
        title: entry.0,
        schedule: entry.1,
        reminder: .default,
        createdAt: createdAt,
        updatedAt: createdAt,
        photo: photos[index]
      )
    }
  }
}
