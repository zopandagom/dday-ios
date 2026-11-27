import Core
import Foundation

/// 저장된 사진의 목록용 정보. 압축본은 `DDayStoreClient.fetchPhoto(id:)` 로만 읽는다.
public struct DDayPhoto: Hashable, Sendable {
  /// 사진 버전 id. 사진을 바꿀 때마다 저장소가 새로 만든다 (캐시·`.task(id:)` 키, 압축본 행과의 짝 확인).
  /// `updatedAt` 은 제목만 바꿔도 바뀌어 사진 버전으로 쓸 수 없다.
  public let id: UUID
  /// 썸네일 JPEG (`CardPhoto.thumbnail`). 목록은 이것만 쓴다.
  public let thumbnail: Data

  public init(id: UUID, thumbnail: Data) {
    self.id = id
    self.thumbnail = thumbnail
  }
}

/// 추가·수정 때 사진을 어떻게 할지. 추가에서 `.keep`·`.remove` 는 둘 다 "사진 없음".
public enum DDayPhotoChange: Hashable, Sendable {
  /// 저장된 사진을 그대로 둔다.
  case keep
  /// 이 사진으로 바꾼다 (저장소가 새 사진 id 를 만든다).
  case replace(CardPhoto)
  /// 사진을 지운다 (썸네일·압축본 모두).
  case remove
}

/// 사용자가 입력하는 디데이 내용 (추가·수정 입력). 제목은 그대로 저장한다 (공백 정리·빈 제목 거부는 편집 화면이 한다).
public struct DDayDraft: Hashable, Sendable {
  public var title: String
  public var schedule: DDaySchedule
  public var reminder: ReminderSettings
  /// 사진 변경. 기본 `.keep` (수정에서 사진을 건드리지 않음, 추가에서는 사진 없음).
  public var photo: DDayPhotoChange

  public init(
    title: String,
    schedule: DDaySchedule,
    reminder: ReminderSettings = .default,
    photo: DDayPhotoChange = .keep
  ) {
    self.title = title
    self.schedule = schedule
    self.reminder = reminder
    self.photo = photo
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
  /// 저장된 사진 (썸네일). 없으면 nil. 압축본은 `fetchPhoto(id:)` 로 읽는다.
  public let photo: DDayPhoto?

  public init(
    id: UUID,
    title: String,
    schedule: DDaySchedule,
    reminder: ReminderSettings,
    createdAt: Date,
    updatedAt: Date,
    photo: DDayPhoto? = nil
  ) {
    self.id = id
    self.title = title
    self.schedule = schedule
    self.reminder = reminder
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.photo = photo
  }

  /// 수정 화면의 시작값. 사진은 `.keep` (저장된 사진 유지).
  public var draft: DDayDraft {
    DDayDraft(title: self.title, schedule: self.schedule, reminder: self.reminder, photo: .keep)
  }
}
