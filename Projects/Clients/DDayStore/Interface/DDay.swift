import Core
import Foundation

/// 사용자가 입력하는 디데이 내용 (추가·수정 입력). 제목은 그대로 저장한다 (공백 정리·빈 제목 거부는 편집 화면이 한다).
public struct DDayDraft: Hashable, Sendable {
  public var title: String
  public var schedule: DDaySchedule
  public var reminder: ReminderSettings

  public init(title: String, schedule: DDaySchedule, reminder: ReminderSettings = .default) {
    self.title = title
    self.schedule = schedule
    self.reminder = reminder
  }
}

/// 저장된 디데이. 저장소가 만든다.
public struct DDay: Hashable, Sendable, Identifiable {
  public let id: UUID
  public let title: String
  public let schedule: DDaySchedule
  public let reminder: ReminderSettings
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: UUID,
    title: String,
    schedule: DDaySchedule,
    reminder: ReminderSettings,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.title = title
    self.schedule = schedule
    self.reminder = reminder
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// 수정 화면의 시작값.
  public var draft: DDayDraft {
    DDayDraft(title: self.title, schedule: self.schedule, reminder: self.reminder)
  }
}
