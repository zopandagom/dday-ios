import Core
import Foundation

/// 예약할 로컬 알림 하나. 시각은 기기 시간대로 해석한다(시간대 고정 없음).
public struct NotificationRequest: Hashable, Sendable, Identifiable {
  /// 식별자 (Core `PlannedReminder.identifier`). 사용자 데이터를 담으므로 로그에 쓰지 않는다.
  public let id: String
  /// 알림의 디데이. userInfo 로 넣는다 (알림 탭에서 쓴다).
  public let dDayID: UUID
  public let title: String
  public let body: String
  /// 울릴 날짜 (양력).
  public let day: CalendarDay
  /// 울릴 시각.
  public let time: TimeOfDay

  public init(id: String, dDayID: UUID, title: String, body: String, day: CalendarDay, time: TimeOfDay) {
    self.id = id
    self.dDayID = dDayID
    self.title = title
    self.body = body
    self.day = day
    self.time = time
  }
}
