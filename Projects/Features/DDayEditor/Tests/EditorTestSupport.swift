import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
@testable import DDayEditorFeature

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다.
enum EditorSample {
  static let today = EditorSample.day(2026, 11, 26)
  static let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  static let createdAt = Date(timeIntervalSince1970: 100)

  static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
    CalendarDay(year: year, month: month, day: day)!
  }

  static func lunar(_ year: Int, _ month: Int, _ day: Int, leap: Bool = false) -> LunarDate {
    LunarDate(year: year, month: month, day: day, isLeapMonth: leap)
  }

  static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
  }

  /// 저장된 디데이 (id 고정).
  static func dDay(
    title: String = "엄마 생일",
    date: DDayDate = .solar(EditorSample.day(2027, 3, 14)),
    repeatRule: RepeatRule = .yearly,
    countingStyle: CountingStyle = .dDay,
    reminder: ReminderSettings = ReminderSettings(
      isEnabled: true,
      enabledDaysBefore: [0, 30],
      time: EditorSample.time(20, 30)
    )
  ) -> DDay {
    DDay(
      id: self.originalID,
      title: title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: reminder,
      createdAt: self.createdAt,
      updatedAt: self.createdAt
    )
  }
}

/// `onFinished` 로 받은 결과.
@MainActor
final class OutcomeRecorder {
  var outcomes: [DDayEditorOutcome] = []
}

@MainActor
func makeEditor(
  _ mode: DDayEditorMode,
  store: any DDayStoreClient = DDayStoreClientFake(),
  today: CalendarDay = EditorSample.today,
  recorder: OutcomeRecorder = OutcomeRecorder()
) -> DDayEditorModel {
  DDayEditorModel(mode: mode, store: store, today: today, onFinished: { recorder.outcomes.append($0) })
}

/// 수정 모드 모델과 그 디데이가 든 Fake.
@MainActor
func makeEditEditor(
  _ dDay: DDay = EditorSample.dDay(),
  recorder: OutcomeRecorder = OutcomeRecorder()
) -> (DDayEditorModel, DDayStoreClientFake) {
  let fake = DDayStoreClientFake(dDays: [dDay])
  return (makeEditor(.edit(dDay), store: fake, recorder: recorder), fake)
}
