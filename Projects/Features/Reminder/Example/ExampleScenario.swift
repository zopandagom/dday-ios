import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import LocalNotificationInterface
import LocalNotificationTesting

/// 시나리오의 저장소·알림 클라이언트. `fake` 는 상태를 바꾸고(설정에서 허용) 대기 요청을 보는 데 쓴다.
struct ExampleSetup {
  let store: any DDayStoreClient
  let notifications: any LocalNotificationClient
  let fake: LocalNotificationClientFake
}

/// Example 앱에서 고르는 권한·실패 상태 (개발용 문구라 카탈로그 밖).
enum ExampleScenario: String, CaseIterable, Identifiable {
  case allowed
  case denied
  case notDeterminedThenAllow
  case notDeterminedThenDeny
  case provisional
  case scheduleFailed
  case loadFailed

  var id: Self { self }

  var title: String {
    switch self {
    case .allowed: "허용"
    case .denied: "거부"
    case .notDeterminedThenAllow: "미결정 → 요청하면 허용"
    case .notDeterminedThenDeny: "미결정 → 요청하면 거부"
    case .provisional: "임시 허용"
    case .scheduleFailed: "예약 실패 (교체 늘 실패)"
    case .loadFailed: "저장소 읽기 실패"
    }
  }

  func makeSetup(today: CalendarDay) -> ExampleSetup {
    let store = DDayStoreClientFake(dDays: ExampleDDays.samples(today: today))
    switch self {
    case .allowed:
      return Self.setup(store, LocalNotificationClientFake(status: .authorized))
    case .denied:
      return Self.setup(store, LocalNotificationClientFake(status: .denied))
    case .notDeterminedThenAllow:
      return Self.setup(store, LocalNotificationClientFake(status: .notDetermined, statusAfterRequest: .authorized))
    case .notDeterminedThenDeny:
      return Self.setup(store, LocalNotificationClientFake(status: .notDetermined, statusAfterRequest: .denied))
    case .provisional:
      return Self.setup(store, LocalNotificationClientFake(status: .provisional))
    case .scheduleFailed:
      let fake = LocalNotificationClientFake(status: .authorized)
      return ExampleSetup(store: store, notifications: ReplaceFailingNotificationClient(base: fake), fake: fake)
    case .loadFailed:
      let fake = LocalNotificationClientFake(status: .authorized)
      return ExampleSetup(store: LoadFailingStore(base: store), notifications: fake, fake: fake)
    }
  }

  private static func setup(_ store: DDayStoreClientFake, _ fake: LocalNotificationClientFake) -> ExampleSetup {
    ExampleSetup(store: store, notifications: fake, fake: fake)
  }
}

/// 직접 만든 샘플 디데이 (오늘 기준 상대 날짜, 개인 데이터 없음).
enum ExampleDDays {
  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
  }

  static func samples(today: CalendarDay) -> [DDay] {
    let examDay = today.adding(days: 7) ?? today
    let birthdayThisYear = today.adding(days: 40) ?? today
    let birthday = CalendarDay(
      year: birthdayThisYear.year - 20,
      month: birthdayThisYear.month,
      day: birthdayThisYear.day
    ) ?? today
    let coupleStart = today.adding(days: -95) ?? today
    let studyStart = today.adding(days: 2) ?? today
    let cafeDay = today.adding(days: 3) ?? today
    return [
      self.dDay(1, "기말고사", DDaySchedule(date: .solar(examDay), repeatRule: .none, countingStyle: .dDay), .default),
      self.dDay(
        2,
        "엄마 생신",
        DDaySchedule(date: .solar(birthday), repeatRule: .yearly, countingStyle: .dDay),
        self.reminder([0, 30])
      ),
      self.dDay(
        3,
        "우리 사귄 날",
        DDaySchedule(date: .solar(coupleStart), repeatRule: .none, countingStyle: .dPlus),
        .default
      ),
      self.dDay(
        4,
        "매일 공부하기",
        DDaySchedule(date: .solar(studyStart), repeatRule: .none, countingStyle: .dayOne),
        self.reminder([0])
      ),
      self.dDay(
        5,
        "카페 오픈 (알림 끔)",
        DDaySchedule(date: .solar(cafeDay), repeatRule: .none, countingStyle: .dDay),
        self.reminder([0, 2, 7], isEnabled: false)
      ),
    ]
  }

  private static func reminder(_ daysBefore: Set<Int>, isEnabled: Bool = true) -> ReminderSettings {
    ReminderSettings(isEnabled: isEnabled, enabledDaysBefore: daysBefore, time: .defaultReminderTime)
  }

  private static func dDay(
    _ number: Int,
    _ title: String,
    _ schedule: DDaySchedule,
    _ reminder: ReminderSettings
  ) -> DDay {
    let createdAt = Date(timeIntervalSince1970: TimeInterval(number * 60))
    return DDay(
      id: self.id(number),
      title: title,
      schedule: schedule,
      reminder: reminder,
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }
}
