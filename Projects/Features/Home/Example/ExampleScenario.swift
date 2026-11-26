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

  var id: Self { self }

  var title: String {
    switch self {
    case .normal: "정상"
    case .empty: "빈 목록"
    case .loadFailed: "불러오기 오류 (다시 시도·앱 복귀로 회복)"
    case .deleteFailed: "삭제 실패"
    }
  }

  /// 이 시나리오의 모델. `today` 는 넘긴 `clock` 인스턴스에서 구한다.
  @MainActor
  func makeModel(clock: ExampleClock) -> HomeModel {
    let store: any DDayStoreClient
    switch self {
    case .normal:
      store = DDayStoreClientFake(dDays: ExampleSamples.dDays(today: clock.today()))
    case .empty:
      store = DDayStoreClientFake()
    case .loadFailed:
      // 저장소 열기 실패도 이렇게(첫 불러오기의 .loadFailed) 보인다.
      let fake = DDayStoreClientFake(dDays: ExampleSamples.dDays(today: clock.today()))
      fake.failNextCall(with: .loadFailed)
      store = fake
    case .deleteFailed:
      store = DeleteFailingStore(base: DDayStoreClientFake(dDays: ExampleSamples.dDays(today: clock.today())))
    }
    return HomeModel(
      store: store,
      today: { clock.today() },
      onAddTapped: {},
      onDDaySelected: { _ in }
    )
  }
}

/// 실제 오늘 기준 상대 날짜로 만든 샘플. 네 그룹(다가오는·세는 중·지난·계산 불가)이 모두 나온다.
enum ExampleSamples {
  static func dDays(today: CalendarDay) -> [DDay] {
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
        updatedAt: createdAt
      )
    }
  }
}
