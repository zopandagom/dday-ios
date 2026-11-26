import Core
import DDayStoreInterface
import Foundation
import Synchronization

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다.
enum Sample {
  static func solar(_ year: Int, _ month: Int, _ day: Int) -> DDayDate {
    .solar(CalendarDay(year: year, month: month, day: day)!)
  }

  static func lunar(_ year: Int, _ month: Int, _ day: Int, leap: Bool = false) -> DDayDate {
    .lunar(LunarDate(year: year, month: month, day: day, isLeapMonth: leap))
  }

  static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
  }

  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
  }

  static func draft(
    _ title: String = "생일",
    date: DDayDate = Sample.solar(2026, 11, 26),
    repeatRule: RepeatRule = .none,
    countingStyle: CountingStyle = .dDay,
    reminder: ReminderSettings = .default
  ) -> DDayDraft {
    DDayDraft(
      title: title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: reminder
    )
  }
}

/// 부를 때마다 1초씩 늘어나는 시계.
final class TestClock: Sendable {
  private let current: Mutex<Date>

  init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
    self.current = Mutex(start)
  }

  func next() -> Date {
    self.current.withLock { date in
      date = date.addingTimeInterval(1)
      return date
    }
  }
}

/// 정해 둔 id 를 차례로 돌려준다. 다 쓰면 새 UUID.
final class IDSequence: Sendable {
  private let remaining: Mutex<[UUID]>

  init(_ ids: [UUID]) {
    self.remaining = Mutex(ids)
  }

  func next() -> UUID {
    self.remaining.withLock { ids in
      ids.isEmpty ? UUID() : ids.removeFirst()
    }
  }
}
