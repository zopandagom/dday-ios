import Core
import DDayStoreInterface
import Foundation
import LocalNotificationInterface

/// 디데이 목록에서 예약할 알림 요청 목록을 만든다 (순수 함수). 고르기·정렬·60 한도는 Core `NotificationPlanner` 가 하고,
/// 여기서는 디데이 설정을 계획기 입력으로 바꾸고 결과에 식별자·제목·본문을 붙인다.
/// - 제목은 디데이 제목 그대로(빈 제목·긴 제목도 바꾸지 않는다), 본문은 `body(문구 종류)`.
/// - 세는 방식은 디데이 id 로 찾은 디데이의 것을 쓴다 (같은 id 가 여럿이면 처음 것).
enum ReminderRequestBuilder {
  static func requests(
    for dDays: [DDay],
    today: CalendarDay,
    now: TimeOfDay,
    body: (ReminderMessageKind) -> String = ReminderText.body
  ) -> [NotificationRequest] {
    let sources = dDays.map { dDay in
      ReminderSource(
        dDayID: dDay.id,
        schedule: dDay.schedule,
        daysBefore: dDay.reminder.scheduledDaysBefore,
        time: dDay.reminder.time,
        remindsEveryHundredDays: dDay.reminder.remindsEveryHundredDays,
        remindsAnniversaries: dDay.reminder.remindsAnniversaries
      )
    }
    let dDaysByID = Dictionary(dDays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    return NotificationPlanner.plan(sources, today: today, now: now).compactMap { planned in
      guard let dDay = dDaysByID[planned.dDayID] else { return nil }
      return NotificationRequest(
        id: planned.identifier,
        dDayID: planned.dDayID,
        title: dDay.title,
        body: body(planned.messageKind(countingStyle: dDay.schedule.countingStyle)),
        day: planned.day,
        time: planned.time
      )
    }
  }
}
