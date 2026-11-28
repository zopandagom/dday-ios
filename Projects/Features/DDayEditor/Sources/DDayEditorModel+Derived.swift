import Core
import DDayStoreInterface
import Foundation
import PhotoInterface

public extension DDayEditorModel {
  // MARK: - 파생 값

  /// 화면 제목용: 추가 모드로 열었는지.
  internal var isAddMode: Bool { self.mode == .add }

  var hasChanges: Bool { self.draft != self.initialDraft }
  /// 끌어내려 닫기를 막는다 (`interactiveDismissDisabled`). 사진 처리 중에도 막는다.
  var isDismissDisabled: Bool { self.isBusy || self.hasChanges || self.isPhotoBusy }

  /// 닫을 때 알릴 결과: 원래 디데이가 없다고 알았으면 지워진 것으로, 아니면 취소.
  internal var closeOutcome: DDayEditorOutcome {
    if self.isOriginalMissing, case let .edit(original) = self.mode {
      return .deleted(original.id)
    }
    return .cancelled
  }

  // MARK: - 폴더

  /// 고를 수 있는 폴더 (열 때 받은 값, 바뀌지 않는다).
  var folders: [DDayFolder] { self.folderSelection.folders }
  /// 고른 폴더. nil 이면 미분류. 늘 nil 이거나 `folders` 안의 id.
  var folderID: UUID? { self.folderSelection.folderID }

  var calendarKind: CalendarKind {
    switch self.date {
    case .solar: .solar
    case .lunar: .lunar
    }
  }

  /// 앞뒤 공백을 정리하면 빈 제목.
  var isTitleEmpty: Bool { Self.trimmed(self.title).isEmpty }
  /// 사진 처리 중에는 저장하지 않는다.
  var canSave: Bool { !self.isTitleEmpty && self.phase == .editing && self.photoStep == .idle }
  var isBusy: Bool { self.phase == .saving || self.phase == .deleting }
  /// 기념일 알림 토글은 D+·1일째 방식일 때만 보인다 (값은 늘 저장).
  var showsMilestoneReminders: Bool { self.countingStyle != .dDay }
  /// 알림 날짜 줄의 표시 순서: 30일 전 → 7일 전 → 2일 전 → 당일.
  static let reminderDayChoices: [Int] = ReminderSettings.daysBeforeChoices.reversed()

  // MARK: - 사진

  /// 추가: `.none`, 수정: 저장된 사진이 있으면 `.stored`.
  var photo: EditorPhoto { self.photoState.photo }
  var photoStep: PhotoStep { self.photoState.step }
  var photoNotice: PhotoNotice? { self.photoState.notice }

  /// 저장할 사진 변경. none: 처음 사진이 있었으면 `.remove` 아니면 `.keep` / stored: `.keep` / new: `.replace`.
  var photoChange: DDayPhotoChange {
    switch self.photo {
    case .none: self.originalPhoto == nil ? .keep : .remove
    case .stored: .keep
    case let .new(cardPhoto): .replace(cardPhoto)
    }
  }

  /// 미리보기 썸네일 JPEG. 사진이 없으면 nil.
  var photoPreviewThumbnail: Data? {
    switch self.photo {
    case .none: nil
    case let .stored(photo): photo.thumbnail
    case let .new(cardPhoto): cardPhoto.thumbnail
    }
  }

  var hasPhoto: Bool { self.photo != .none }
  var isPhotoBusy: Bool { self.photoStep != .idle }
  var canPickPhoto: Bool { self.phase == .editing && self.photoState.isIdle }

  /// 자르기·만들기 중인 작업 이미지.
  var cropImage: PhotoWorkingImage? {
    switch self.photoStep {
    case let .cropping(image), let .rendering(image): image
    case .idle, .loading: nil
    }
  }

  /// 자르기 화면 push. 버리기 확인창이 떠 있는 동안은 미룬다.
  var isCropPresented: Bool { self.cropImage != nil && !self.isDiscardConfirmationPresented }
  var isRendering: Bool {
    if case .rendering = self.photoStep {
      return true
    }
    return false
  }

  /// "이미 지워진 디데이" 알림 본문을 사진 문구로 할지: 저장된 사진을 잃었고 지금도 사진이 없을 때만.
  var isPhotoLostMessageShown: Bool { self.isStoredPhotoLost && self.photo == .none }

  /// 저장할 값: 제목 정리, 알림은 `ReminderSettings` 가 정규화.
  internal var draft: DDayDraft {
    DDayDraft(
      title: Self.trimmed(self.title),
      schedule: DDaySchedule(date: self.date, repeatRule: self.repeatRule, countingStyle: self.countingStyle),
      reminder: ReminderSettings(
        isEnabled: self.reminderIsEnabled,
        enabledDaysBefore: self.enabledReminderDays,
        time: self.reminderTime,
        remindsEveryHundredDays: self.remindsEveryHundredDays,
        remindsAnniversaries: self.remindsAnniversaries
      ),
      photo: self.photoChange,
      folderID: self.folderSelection.savedFolderID
    )
  }

  /// 음력 선택기의 선택지. 양력이면 같은 날의 음력 기준.
  internal var lunarChoices: LunarPickerOptions.Choices {
    switch self.date {
    case let .lunar(lunar):
      return LunarPickerOptions.choices(for: lunar)
    case let .solar(day):
      let lunar = KoreanLunarCalendar.lunarDate(from: day)
        ?? LunarPickerOptions.normalized(year: day.year, month: 1, isLeapMonth: false, day: 1)
      return LunarPickerOptions.choices(for: lunar)
    }
  }

  // MARK: - 날짜·제목 정리

  internal static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  internal static func clampedSolar(_ day: CalendarDay) -> CalendarDay {
    let range = KoreanLunarCalendar.supportedSolarRange
    return min(max(day, range.lowerBound), range.upperBound)
  }

  /// 고를 수 있는 날짜로 맞춘 값과 맞췄는지.
  internal static func selectable(_ date: DDayDate) -> (DDayDate, Bool) {
    switch date {
    case let .solar(day):
      let clamped = self.clampedSolar(day)
      return (.solar(clamped), clamped != day)
    case let .lunar(lunar):
      guard KoreanLunarCalendar.solarDay(from: lunar) == nil else { return (date, false) }
      let normalized = LunarPickerOptions.normalized(
        year: lunar.year,
        month: lunar.month,
        isLeapMonth: lunar.isLeapMonth,
        day: lunar.day
      )
      return (.lunar(normalized), true)
    }
  }
}
