import Core
import DDayStoreInterface
import Foundation

/// `DDayRecord` 의 필드 값 사본. 순수 변환과 테스트가 컨테이너 없이 쓰도록 분리한다.
struct DDayRecordFields: Hashable, Sendable {
  var id: UUID
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
  var reminderDisabledDaysBefore: [Int]
  var reminderEveryHundredDays: Bool
  var reminderAnniversaries: Bool
  var reminderHour: Int
  var reminderMinute: Int
  var createdAt: Date
  var updatedAt: Date
  /// 폴더 id. 쓰기는 그대로 옮기고, 읽기는 `dDay(from:photo:folderIDs:)` 가 정규화한다.
  var folderID: UUID?
}

/// 저장값 ↔ Core 값 변환.
///
/// - 저장 문자열은 여기에 리터럴로 적는다. Core enum 의 `rawValue` 를 쓰지 않아 Core 의 case 이름이 바뀌어도
///   저장 형식이 바뀌지 않는다. 쓰기 `switch` 는 `default` 없이 써서 Core 에 case 가 늘면 컴파일 에러가 난다.
/// - 원칙: 쓰기가 만들 수 있는 값은 모두 읽는다. 읽기 실패(`nil`)는 쓰기가 만들 수 없는 값(모르는 문자열,
///   없는 양력 날짜, 양력인데 윤달 표시, 범위 밖 시각)에만 한다. 음력 날짜는 유효성을 보지 않는다
///   (`LunarDate` 는 어떤 정수 조합이든 만들 수 있고 유효성은 쓸 때 `KoreanLunarCalendar` 가 판단한다).
///   알림 날짜도 읽기 실패로 보지 않고 `ReminderSettings` 가 정규화한다 (고정 선택지 밖 값은 버린다. 켜짐은 켜진
///   필드만으로 정한다).
/// - 알림 날짜: 켜진 날짜는 `reminderDaysBefore`, 나머지 선택지는 `reminderDisabledDaysBefore` (각각 오름차순).
///   읽기는 켜진 필드만 본다.
/// - 기념일 토글: `reminderEveryHundredDays`·`reminderAnniversaries` (그대로 옮긴다).
/// - 사진: `photoID`·`photoThumbnail` 이 둘 다 있을 때만 사진이다. 사진 필드는 `DDayRecordFields` 에 넣지 않는다.
/// - 폴더: `folderID` 는 읽을 수 있는 폴더 id 집합에 있을 때만 그대로, 아니면 미분류(nil). 행은 읽는다.
///   쓰기는 draft 의 값을 그대로 옮긴다 (없는 폴더 id 를 nil 로 바꾸는 정규화는 Impl 이 쓰기 전에 한다).
enum DDayRecordMapping {
  static func fields(id: UUID, draft: DDayDraft, createdAt: Date, updatedAt: Date) -> DDayRecordFields {
    let dateKind: String
    let year: Int
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    switch draft.schedule.date {
    case let .solar(solar):
      dateKind = DateKind.solar
      (year, month, day, isLeapMonth) = (solar.year, solar.month, solar.day, false)
    case let .lunar(lunar):
      dateKind = DateKind.lunar
      (year, month, day, isLeapMonth) = (lunar.year, lunar.month, lunar.day, lunar.isLeapMonth)
    }
    return DDayRecordFields(
      id: id,
      title: draft.title,
      dateKind: dateKind,
      dateYear: year,
      dateMonth: month,
      dateDay: day,
      dateIsLeapMonth: isLeapMonth,
      repeatRule: self.string(for: draft.schedule.repeatRule),
      countingStyle: self.string(for: draft.schedule.countingStyle),
      reminderIsEnabled: draft.reminder.isEnabled,
      reminderDaysBefore: draft.reminder.enabledDaysBefore.sorted(),
      reminderDisabledDaysBefore: ReminderSettings.daysBeforeChoices
        .filter { !draft.reminder.enabledDaysBefore.contains($0) },
      reminderEveryHundredDays: draft.reminder.remindsEveryHundredDays,
      reminderAnniversaries: draft.reminder.remindsAnniversaries,
      reminderHour: draft.reminder.time.hour,
      reminderMinute: draft.reminder.time.minute,
      createdAt: createdAt,
      updatedAt: updatedAt,
      folderID: draft.folderID
    )
  }

  static func fields(of dDay: DDay) -> DDayRecordFields {
    self.fields(id: dDay.id, draft: dDay.draft, createdAt: dDay.createdAt, updatedAt: dDay.updatedAt)
  }

  /// 행의 사진 필드 → 목록용 사진. 둘 다 있으면 사진, 하나라도 없으면 nil (행은 읽는다).
  static func photo(id: UUID?, thumbnail: Data?) -> DDayPhoto? {
    guard let id, let thumbnail else { return nil }
    return DDayPhoto(id: id, thumbnail: thumbnail)
  }

  /// 읽을 수 없는 값이면 nil. 사진은 `photo(id:thumbnail:)` 로 따로 구해 넘긴다 (사진 필드는 `DDayRecordFields` 밖).
  /// - Parameter folderIDs: 읽을 수 있는 폴더 id 전부. `fields.folderID` 가 여기 없으면 미분류(nil)로 읽는다.
  ///   빼먹지 않도록 기본값을 두지 않는다.
  static func dDay(from fields: DDayRecordFields, photo: DDayPhoto? = nil, folderIDs: Set<UUID>) -> DDay? {
    guard let date = self.date(from: fields),
          let repeatRule = self.repeatRule(from: fields.repeatRule),
          let countingStyle = self.countingStyle(from: fields.countingStyle),
          let time = TimeOfDay(hour: fields.reminderHour, minute: fields.reminderMinute)
    else {
      return nil
    }
    return DDay(
      id: fields.id,
      title: fields.title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: ReminderSettings(
        isEnabled: fields.reminderIsEnabled,
        enabledDaysBefore: Set(fields.reminderDaysBefore),
        time: time,
        remindsEveryHundredDays: fields.reminderEveryHundredDays,
        remindsAnniversaries: fields.reminderAnniversaries
      ),
      createdAt: fields.createdAt,
      updatedAt: fields.updatedAt,
      photo: photo,
      folderID: fields.folderID.flatMap { folderIDs.contains($0) ? $0 : nil }
    )
  }

  // MARK: - 저장 문자열 (V1, 출시 뒤 바꾸지 않는다)

  enum DateKind {
    static let solar = "solar"
    static let lunar = "lunar"
  }

  static func string(for repeatRule: RepeatRule) -> String {
    switch repeatRule {
    case .none: "none"
    case .yearly: "yearly"
    }
  }

  static func string(for countingStyle: CountingStyle) -> String {
    switch countingStyle {
    case .dDay: "dDay"
    case .dPlus: "dPlus"
    case .dayOne: "dayOne"
    }
  }

  private static func repeatRule(from string: String) -> RepeatRule? {
    switch string {
    case "none": RepeatRule.none
    case "yearly": .yearly
    default: nil
    }
  }

  private static func countingStyle(from string: String) -> CountingStyle? {
    switch string {
    case "dDay": .dDay
    case "dPlus": .dPlus
    case "dayOne": .dayOne
    default: nil
    }
  }

  private static func date(from fields: DDayRecordFields) -> DDayDate? {
    switch fields.dateKind {
    case DateKind.solar:
      guard !fields.dateIsLeapMonth,
            let solar = CalendarDay(year: fields.dateYear, month: fields.dateMonth, day: fields.dateDay)
      else {
        return nil
      }
      return .solar(solar)
    case DateKind.lunar:
      return .lunar(
        LunarDate(
          year: fields.dateYear,
          month: fields.dateMonth,
          day: fields.dateDay,
          isLeapMonth: fields.dateIsLeapMonth
        )
      )
    default:
      return nil
    }
  }
}
