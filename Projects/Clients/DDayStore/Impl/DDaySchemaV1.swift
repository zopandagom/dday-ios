import Foundation
import SwiftData

/// V1 저장 형식 (1.0.0). 출시 뒤에는 필드·저장 문자열을 고치지 않는다 (PRODUCT §3). 바꿀 때는 V2 + 마이그레이션 단계.
enum DDaySchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)
  static var models: [any PersistentModel.Type] { [DDayRecord.self] }

  /// 디데이 한 행. 모두 기본 타입의 평평한 필드다 (중첩 구조체·관계 없음). 값의 뜻은 `DDayRecordMapping` 이 정한다.
  @Model
  final class DDayRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var dateKind: String
    var dateYear: Int
    var dateMonth: Int
    var dateDay: Int
    var dateIsLeapMonth: Bool
    var repeatRule: String
    var countingStyle: String
    var reminderIsEnabled: Bool
    var reminderDaysBefore: [Int]
    var reminderHour: Int
    var reminderMinute: Int
    var createdAt: Date
    var updatedAt: Date

    init(_ fields: DDayRecordFields) {
      self.id = fields.id
      self.title = fields.title
      self.dateKind = fields.dateKind
      self.dateYear = fields.dateYear
      self.dateMonth = fields.dateMonth
      self.dateDay = fields.dateDay
      self.dateIsLeapMonth = fields.dateIsLeapMonth
      self.repeatRule = fields.repeatRule
      self.countingStyle = fields.countingStyle
      self.reminderIsEnabled = fields.reminderIsEnabled
      self.reminderDaysBefore = fields.reminderDaysBefore
      self.reminderHour = fields.reminderHour
      self.reminderMinute = fields.reminderMinute
      self.createdAt = fields.createdAt
      self.updatedAt = fields.updatedAt
    }

    /// id 를 뺀 모든 필드를 `fields` 로 바꾼다 (같은 값도 대입해 나중 저장이 draft 전체로 이기게 한다).
    func apply(_ fields: DDayRecordFields) {
      self.title = fields.title
      self.dateKind = fields.dateKind
      self.dateYear = fields.dateYear
      self.dateMonth = fields.dateMonth
      self.dateDay = fields.dateDay
      self.dateIsLeapMonth = fields.dateIsLeapMonth
      self.repeatRule = fields.repeatRule
      self.countingStyle = fields.countingStyle
      self.reminderIsEnabled = fields.reminderIsEnabled
      self.reminderDaysBefore = fields.reminderDaysBefore
      self.reminderHour = fields.reminderHour
      self.reminderMinute = fields.reminderMinute
      self.createdAt = fields.createdAt
      self.updatedAt = fields.updatedAt
    }

    /// 지금 필드 값의 사본.
    var fields: DDayRecordFields {
      DDayRecordFields(
        id: self.id,
        title: self.title,
        dateKind: self.dateKind,
        dateYear: self.dateYear,
        dateMonth: self.dateMonth,
        dateDay: self.dateDay,
        dateIsLeapMonth: self.dateIsLeapMonth,
        repeatRule: self.repeatRule,
        countingStyle: self.countingStyle,
        reminderIsEnabled: self.reminderIsEnabled,
        reminderDaysBefore: self.reminderDaysBefore,
        reminderHour: self.reminderHour,
        reminderMinute: self.reminderMinute,
        createdAt: self.createdAt,
        updatedAt: self.updatedAt
      )
    }
  }
}

typealias DDayRecord = DDaySchemaV1.DDayRecord
