import Core
import DDayEditorFeature
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import PhotoInterface
import PhotoTesting

/// 시나리오의 편집 모드·저장소·사진 클라이언트. `fake` 는 저장된 디데이 수를 보여 주는 데 쓴다.
/// 사진은 Fake 선택 버튼(`PhotoPickerButtonFake`)의 메뉴로 고른다 (가로·세로 샘플, 읽기 실패).
struct ExampleSetup {
  let mode: DDayEditorMode
  let store: any DDayStoreClient
  let fake: DDayStoreClientFake
  var photoClient: any PhotoClient = PhotoClientFake()
}

/// Example 앱에서 고르는 편집 화면 상태 (설계 §8.3).
enum ExampleScenario: String, CaseIterable, Identifiable {
  case addEmptyTitle
  case editSolarYearly
  case editLunarLeap
  case lunarBoundary
  case dPlusReminder
  case saveFailed
  case alreadyDeleted
  case deleteFailed
  case slowStore
  case unsupportedDate
  case editWithPhoto
  case photoDecodeFailed
  case photoTooLarge
  case photoRenderFailed
  case slowPhoto
  case alreadyDeletedWithPhoto

  var id: Self { self }

  var title: String {
    switch self {
    case .addEmptyTitle: "추가 (빈 제목 검증)"
    case .editSolarYearly: "수정 (양력·매년)"
    case .editLunarLeap: "수정 (음력 윤달)"
    case .lunarBoundary: "음력 경계 (2050-11-10)"
    case .dPlusReminder: "D+ 기념일 알림"
    case .saveFailed: "저장 실패 (한 번)"
    case .alreadyDeleted: "이미 지워진 디데이"
    case .deleteFailed: "삭제 실패"
    case .slowStore: "느린 저장소 (중복 탭)"
    case .unsupportedDate: "지원 안 되는 저장 날짜 (음력 2026 윤6-1)"
    case .editWithPhoto: "수정 (사진 있음: 바꾸기·지우기)"
    case .photoDecodeFailed: "사진 디코딩 실패 (한 번)"
    case .photoTooLarge: "사진 너무 큼 (한 번)"
    case .photoRenderFailed: "사진 만들기 실패 (한 번, 다시 시도)"
    case .slowPhoto: "느린 사진 처리 (3초: 불러오기 취소·편집 취소)"
    case .alreadyDeletedWithPhoto: "이미 지워진 디데이 (사진 있음)"
    }
  }

  /// 이 시나리오의 편집 모드와 저장소.
  func makeSetup() -> ExampleSetup {
    switch self {
    case .addEmptyTitle:
      let fake = DDayStoreClientFake()
      return ExampleSetup(mode: .add, store: fake, fake: fake)
    case .editSolarYearly:
      return Self.editing(ExampleSamples.birthday)
    case .editLunarLeap:
      return Self.editing(ExampleSamples.dDay(
        "윤달 기념일",
        .lunar(LunarDate(year: 2025, month: 6, day: 29, isLeapMonth: true))
      ))
    case .lunarBoundary:
      return Self.editing(ExampleSamples.dDay("먼 미래", .lunar(LunarDate(year: 2050, month: 11, day: 10))))
    case .dPlusReminder:
      return Self.editing(ExampleSamples.dDay(
        "우리 만난 날",
        .solar(CalendarDay(year: 2025, month: 5, day: 1) ?? ExampleSamples.fallbackDay),
        countingStyle: .dPlus
      ))
    case .saveFailed, .alreadyDeleted, .deleteFailed, .slowStore:
      return self.makeStoreFailureSetup() ?? Self.editing(ExampleSamples.birthday)
    case .unsupportedDate:
      return Self.editing(ExampleSamples.dDay(
        "윤달 기념일",
        .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true))
      ))
    case .editWithPhoto, .photoDecodeFailed, .photoTooLarge, .photoRenderFailed, .slowPhoto, .alreadyDeletedWithPhoto:
      return self.makePhotoSetup() ?? Self.editingWithPhoto()
    }
  }

  /// 저장소 실패·지연 시나리오의 편집 모드와 저장소. 그런 시나리오가 아니면 nil.
  private func makeStoreFailureSetup() -> ExampleSetup? {
    switch self {
    case .saveFailed:
      let setup = Self.editing(ExampleSamples.birthday)
      setup.fake.failNextCall(with: .saveFailed)
      return setup
    case .alreadyDeleted:
      let fake = DDayStoreClientFake()
      return ExampleSetup(mode: .edit(ExampleSamples.birthday), store: fake, fake: fake)
    case .deleteFailed:
      let fake = DDayStoreClientFake(dDays: [ExampleSamples.birthday])
      return ExampleSetup(mode: .edit(ExampleSamples.birthday), store: DeleteFailingStore(base: fake), fake: fake)
    case .slowStore:
      let fake = DDayStoreClientFake(dDays: [ExampleSamples.birthday])
      return ExampleSetup(mode: .edit(ExampleSamples.birthday), store: SlowStore(base: fake), fake: fake)
    default:
      return nil
    }
  }

  /// 사진 시나리오의 편집 모드와 저장소. 사진 시나리오가 아니면 nil.
  private func makePhotoSetup() -> ExampleSetup? {
    switch self {
    case .editWithPhoto:
      return Self.editingWithPhoto()
    case .photoDecodeFailed:
      return Self.adding(failingLoad: .decodeFailed)
    case .photoTooLarge:
      return Self.adding(failingLoad: .tooLarge)
    case .photoRenderFailed:
      let photoClient = PhotoClientFake()
      photoClient.failNextRender(with: .renderFailed)
      let fake = DDayStoreClientFake()
      return ExampleSetup(mode: .add, store: fake, fake: fake, photoClient: photoClient)
    case .slowPhoto:
      var setup = Self.editingWithPhoto()
      setup.photoClient = PhotoClientFake(delay: .seconds(3))
      return setup
    case .alreadyDeletedWithPhoto:
      let fake = DDayStoreClientFake()
      return ExampleSetup(mode: .edit(ExampleSamples.birthdayWithPhoto), store: fake, fake: fake)
    default:
      return nil
    }
  }

  /// Preview 용 모델 (결과는 버린다).
  @MainActor
  func makePreviewModel() -> DDayEditorModel {
    let setup = self.makeSetup()
    return DDayEditorModel(
      mode: setup.mode,
      store: setup.store,
      photoClient: setup.photoClient,
      today: CalendarDay(Date(), in: .autoupdatingCurrent),
      onFinished: { _ in }
    )
  }

  private static func editing(_ dDay: DDay) -> ExampleSetup {
    let fake = DDayStoreClientFake(dDays: [dDay])
    return ExampleSetup(mode: .edit(dDay), store: fake, fake: fake)
  }

  /// 사진 있는 디데이와 그 압축본이 든 Fake.
  private static func editingWithPhoto() -> ExampleSetup {
    let dDay = ExampleSamples.birthdayWithPhoto
    let fake = DDayStoreClientFake(dDays: [dDay], photoImages: [dDay.id: ExampleSamples.cardPhoto.image])
    return ExampleSetup(mode: .edit(dDay), store: fake, fake: fake)
  }

  /// 다음 불러오기 한 번이 `error` 로 실패하는 추가 화면.
  private static func adding(failingLoad error: PhotoError) -> ExampleSetup {
    let photoClient = PhotoClientFake()
    photoClient.failNextLoad(with: error)
    let fake = DDayStoreClientFake()
    return ExampleSetup(mode: .add, store: fake, fake: fake, photoClient: photoClient)
  }
}

enum ExampleSamples {
  static let fallbackDay = CalendarDay(Date(), in: .autoupdatingCurrent)

  static let birthday = ExampleSamples.dDay(
    "엄마 생일",
    .solar(CalendarDay(year: 2027, month: 3, day: 14) ?? ExampleSamples.fallbackDay),
    repeatRule: .yearly,
    // 30일 전·7일 전·당일 켜짐, 2일 전 꺼짐: 저장값이 기본값과 다르게 보이도록.
    reminder: ReminderSettings(enabledDaysBefore: [0, 7, 30], time: .defaultReminderTime)
  )

  /// 직접 만든 샘플 사진 (개인 데이터 아님).
  static let cardPhoto = PhotoSamples.cardPhoto(seed: 1)

  static let birthdayWithPhoto = ExampleSamples.dDay(
    "엄마 생일",
    .solar(CalendarDay(year: 2027, month: 3, day: 14) ?? ExampleSamples.fallbackDay),
    repeatRule: .yearly,
    photo: DDayPhoto(id: UUID(), thumbnail: ExampleSamples.cardPhoto.thumbnail)
  )

  static func dDay(
    _ title: String,
    _ date: DDayDate,
    repeatRule: RepeatRule = .none,
    countingStyle: CountingStyle = .dDay,
    reminder: ReminderSettings = .default,
    photo: DDayPhoto? = nil
  ) -> DDay {
    let createdAt = Date(timeIntervalSince1970: 0)
    return DDay(
      id: UUID(),
      title: title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: reminder,
      createdAt: createdAt,
      updatedAt: createdAt,
      photo: photo
    )
  }
}
