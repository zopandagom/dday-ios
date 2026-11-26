import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import HomeFeature

// MARK: - 테스트 지원

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다.
enum HomeSample {
  static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
    CalendarDay(year: year, month: month, day: day)!
  }

  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
  }

  /// id 와 생성 시각이 `number` 로 정해지는 디데이 (번호가 작을수록 먼저 만든 것).
  static func dDay(
    _ number: Int,
    _ date: DDayDate,
    repeatRule: RepeatRule = .none,
    countingStyle: CountingStyle = .dDay
  ) -> DDay {
    let createdAt = Date(timeIntervalSince1970: TimeInterval(number * 10))
    return DDay(
      id: self.id(number),
      title: "디데이 \(number)",
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: .default,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  static func solar(_ year: Int, _ month: Int, _ day: Int) -> DDayDate {
    .solar(self.day(year, month, day))
  }

  /// 기본 오늘.
  static let today = HomeSample.day(2026, 11, 26)

  /// 네 그룹이 섞인 샘플 (생성 순서와 정렬 순서가 다르다). 기대 정렬: 6, 3, 7, 4, 5, 2, 1.
  static let mixed: [DDay] = [
    HomeSample.dDay(1, .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true))), // 계산 불가
    HomeSample.dDay(2, HomeSample.solar(2026, 11, 16)), // 지난 10일
    HomeSample.dDay(3, HomeSample.solar(2026, 11, 29)), // D-3
    HomeSample.dDay(4, HomeSample.solar(2026, 11, 16), countingStyle: .dPlus), // D+10
    HomeSample.dDay(5, HomeSample.solar(2026, 11, 20)), // 지난 6일
    HomeSample.dDay(6, HomeSample.solar(2026, 11, 26)), // D-DAY
    HomeSample.dDay(7, HomeSample.solar(2026, 11, 26), countingStyle: .dayOne), // 1일째
  ]

  static let mixedOrder: [UUID] = [6, 3, 7, 4, 5, 2, 1].map { HomeSample.id($0) }

  /// 하루 지나면 순서가 바뀌는 샘플: 오늘 [11, 10, 12] → 다음 날 [10, 12, 11].
  static let dayShift: [DDay] = [
    HomeSample.dDay(10, HomeSample.solar(2026, 11, 27)), // D-1 → 다음 날 D-DAY
    HomeSample.dDay(11, HomeSample.solar(2026, 11, 26)), // D-DAY → 다음 날 지난 1일
    HomeSample.dDay(12, HomeSample.solar(2026, 11, 20), countingStyle: .dPlus), // D+6 → D+7
  ]
}

@MainActor
final class TestDayClock {
  var day: CalendarDay

  init(_ day: CalendarDay = HomeSample.today) {
    self.day = day
  }
}

@MainActor
final class CallbackRecorder {
  var addCount = 0
  var selected: [DDay] = []
}

extension HomeModel.Content {
  var items: [HomeItem]? {
    if case let .loaded(items) = self {
      return items
    }
    return nil
  }

  var ids: [UUID]? {
    self.items?.map(\.id)
  }
}
