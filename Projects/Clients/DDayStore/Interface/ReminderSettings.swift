import Core

/// 디데이 하나의 알림 설정.
public struct ReminderSettings: Hashable, Sendable {
  /// `false` 면 알림 없음. 끈 동안에도 날짜·시각은 남겨 다시 켤 때 쓴다.
  public let isEnabled: Bool
  /// 며칠 전에 알릴지 (0 = 당일). 음수는 버리고 중복은 하나로, 오름차순. 비어 있으면 알림 없음.
  /// 화면 표시 순서(예: 7일 전 먼저)는 화면이 정한다.
  public let daysBefore: [Int]
  public let time: TimeOfDay

  /// `daysBefore` 는 여기서만 정규화한다 (음수 제거, 중복 제거, 오름차순).
  public init(isEnabled: Bool = true, daysBefore: [Int], time: TimeOfDay) {
    self.isEnabled = isEnabled
    self.daysBefore = Array(Set(daysBefore.filter { $0 >= 0 })).sorted()
    self.time = time
  }

  /// 기본: 켜짐, 당일·2일 전·7일 전([0, 2, 7]), 오전 9시(`TimeOfDay.defaultReminderTime`).
  public static let `default` = ReminderSettings(daysBefore: [0, 2, 7], time: .defaultReminderTime)
}
