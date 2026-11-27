import Core
import DDayStoreInterface
import Foundation
import SwiftData
import Synchronization
@testable import DDayStoreImpl

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
    reminder: ReminderSettings = .default,
    photo: DDayPhotoChange = .keep
  ) -> DDayDraft {
    DDayDraft(
      title: title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: reminder,
      photo: photo
    )
  }

  /// 저장소 테스트용 사진. 저장소는 바이트를 해석하지 않으므로 JPEG 이 아니어도 된다. seed 마다 다르고 image ≠ thumbnail.
  static func cardPhoto(seed: UInt8 = 0) -> CardPhoto {
    CardPhoto(image: Data([0xA0, seed, 0x01, 0x02]), thumbnail: Data([0xB0, seed]))
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

/// 열기 주입용 에러.
struct TestOpenError: Error {}

/// 저장소 열기를 흉내 낸다. 시도 수를 세고, 정한 횟수만큼 실패한 뒤에는 새 메모리 컨테이너를 연다.
final class ContainerOpener: Sendable {
  private let state: Mutex<(attempts: Int, failuresLeft: Int)>

  init(failures: Int = 0) {
    self.state = Mutex((attempts: 0, failuresLeft: failures))
  }

  /// 지금까지 열기를 시도한 횟수.
  var attempts: Int {
    self.state.withLock { $0.attempts }
  }

  func open() throws -> ModelContainer {
    let shouldFail = self.state.withLock { state in
      state.attempts += 1
      guard state.failuresLeft > 0 else { return false }
      state.failuresLeft -= 1
      return true
    }
    if shouldFail {
      throw TestOpenError()
    }
    return try DDayStoreClientImpl.makeContainer(isStoredInMemoryOnly: true)
  }
}
