import Core
import Foundation
import LocalNotificationInterface
import UserNotifications

/// UserNotifications 값과 Interface 값 사이의 변환 (순수, 시스템 호출 없음).
enum NotificationRequestMapping {
  /// userInfo 에 디데이 id(`uuidString`)를 넣는 키.
  static let dDayIDKey = "dDayID"

  /// `ephemeral` 은 App Clip 전용이라 오지 않지만 오면 허용으로 본다. 모르는 값도 허용으로 보고 예약을 시도한다
  /// (허용되지 않았으면 add 가 실패해 `.scheduleFailed` 로그만 남는다. 프롬프트·거부 안내를 잘못 띄우지 않는다).
  static func authorization(from status: UNAuthorizationStatus) -> NotificationAuthorization {
    switch status {
    case .notDetermined: .notDetermined
    case .denied: .denied
    case .authorized: .authorized
    case .provisional: .provisional
    case .ephemeral: .authorized
    @unknown default: .authorized
    }
  }

  /// 그레고리력의 연·월·일·시·분. 시간대는 넣지 않아 기기 시간대로 해석된다.
  /// 달력을 넣지 않으면 기기 달력이 불교력일 때 다음 울림 시각이 없어 울리지 않는다 (시뮬레이터 실행 값).
  static func dateComponents(day: CalendarDay, time: TimeOfDay) -> DateComponents {
    DateComponents(
      calendar: Calendar(identifier: .gregorian),
      year: day.year,
      month: day.month,
      day: day.day,
      hour: time.hour,
      minute: time.minute
    )
  }

  static func content(for request: NotificationRequest) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = request.title
    content.body = request.body
    content.sound = .default
    content.userInfo = [self.dDayIDKey: request.dDayID.uuidString]
    return content
  }

  /// 한 번 울리는 달력 트리거 요청.
  static func request(for request: NotificationRequest) -> UNNotificationRequest {
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: self.dateComponents(day: request.day, time: request.time),
      repeats: false
    )
    return UNNotificationRequest(identifier: request.id, content: self.content(for: request), trigger: trigger)
  }
}
