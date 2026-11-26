import Core

/// 디데이 하나의 알림 설정.
public struct ReminderSettings: Hashable, Sendable {
  /// 고를 수 있는 알림 날짜 (며칠 전, 오름차순). 0 = 당일, 30 = 30일 전.
  /// 정규화·저장 매핑·편집 화면이 같은 값을 쓴다. 화면 표시 순서는 화면이 정한다.
  public static let daysBeforeChoices: [Int] = [0, 2, 7, 30]

  /// `false` 면 알림 없음. 끈 동안에도 켜진 날짜·시각·기념일 토글은 남겨 다시 켤 때 쓴다.
  public let isEnabled: Bool
  /// 켜진 알림 날짜. 늘 `daysBeforeChoices` 의 부분집합이다 (init 이 밖의 값을 버린다). 여기 없는 선택지는 꺼짐.
  public let enabledDaysBefore: Set<Int>
  public let time: TimeOfDay
  /// D+·1일째 방식에서 100일 단위 기념일에도 알린다. dDay 방식에서는 쓰지 않지만 값은 남긴다.
  public let remindsEveryHundredDays: Bool
  /// D+·1일째 방식에서 N주년에도 알린다. dDay 방식에서는 쓰지 않지만 값은 남긴다.
  public let remindsAnniversaries: Bool

  /// 정규화는 여기서만: `enabledDaysBefore` 를 `daysBeforeChoices` 와 교집합한다 (선택지 밖 값은 화면에서
  /// 보거나 끌 수 없으므로 버린다). 기념일 토글은 정규화하지 않고, `isEnabled == false` 여도 그대로 남긴다.
  public init(
    isEnabled: Bool = true,
    enabledDaysBefore: Set<Int>,
    time: TimeOfDay,
    remindsEveryHundredDays: Bool = true,
    remindsAnniversaries: Bool = true
  ) {
    self.isEnabled = isEnabled
    self.enabledDaysBefore = enabledDaysBefore.intersection(Self.daysBeforeChoices)
    self.time = time
    self.remindsEveryHundredDays = remindsEveryHundredDays
    self.remindsAnniversaries = remindsAnniversaries
  }

  /// 알림 계획기에 넘길 값: 전체가 켜져 있으면 켜진 날짜(오름차순), 아니면 `[]`.
  /// 알림 예약은 `ReminderSource(dDayID:schedule:daysBefore: dDay.reminder.scheduledDaysBefore, time:,
  /// remindsEveryHundredDays:, remindsAnniversaries:)` 로 만들고, 기념일 토글은 그대로 넘긴다.
  /// 전체를 끄면 이 값이 [] 라 기념일 알림도 없다.
  public var scheduledDaysBefore: [Int] {
    guard self.isEnabled else { return [] }
    return self.enabledDaysBefore.sorted()
  }

  /// 기본: 켜짐, 당일·2일 전·7일 전 켜짐(30일 전 꺼짐), 오전 9시(`TimeOfDay.defaultReminderTime`),
  /// 기념일 토글 둘 다 켜짐.
  public static let `default` = ReminderSettings(enabledDaysBefore: [0, 2, 7], time: .defaultReminderTime)
}
