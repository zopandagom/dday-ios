import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import HomeFeature

/// Example 앱에서 고르는 화면 상태.
enum ExampleScenario: String, CaseIterable, Identifiable {
  case normal
  case customFolders
  case noFolders
  case folderLoadFailed
  case empty
  case loadFailed
  case deleteFailed
  case brokenThumbnail
  case slowPhotoRead
  case photoReadFailed
  case missingLargePhoto

  var id: Self { self }

  var title: String {
    switch self {
    case .normal: "정상 (기본 폴더만)"
    case .customFolders: "직접 만든 폴더 여럿 (다섯 색 배경)"
    case .noFolders: "폴더 없음 (칩 숨김·기본 배경)"
    case .folderLoadFailed: "폴더 읽기 실패 한 번 (다시 시도로 회복)"
    case .empty: "빈 목록"
    case .loadFailed: "불러오기 오류 (다시 시도·앱 복귀로 회복)"
    case .deleteFailed: "삭제 실패"
    case .brokenThumbnail: "손상된 썸네일 (폴더 색 기본 배경으로 보임)"
    case .slowPhotoRead: "느린 압축본 읽기 (3초)"
    case .photoReadFailed: "압축본 읽기 실패 (상세에 썸네일)"
    case .missingLargePhoto: "압축본 없음 (상세에 썸네일)"
    }
  }

  /// 이 시나리오의 흐름(홈·상세 모델). `today` 는 넘긴 `clock` 인스턴스에서 구한다.
  @MainActor
  func makeFlow(clock: ExampleClock) -> ExampleFlow {
    ExampleFlow(store: self.makeStore(today: clock.today()), today: { clock.today() })
  }

  /// 폴더·목록 상태 시나리오의 저장소. 사진·실패 시나리오는 `makeFailureOrPhotoStore` 가 만든다.
  private func makeStore(today: CalendarDay) -> any DDayStoreClient {
    let samples = ExampleSamples.samples(today: today)
    switch self {
    case .normal:
      return Self.fake(samples)
    case .customFolders:
      return DDayStoreClientFake(
        dDays: samples.dDays,
        photoImages: samples.photoImages,
        folders: DDayStoreClientFake.defaultFolders + ExampleSamples.customFolders
      )
    case .noFolders:
      // 폴더 행 없이 디데이의 folderID 만 남은 저장소(옛 데이터·읽을 수 없는 폴더 행). 모두 미분류로 읽힌다.
      // (폴더 관리로 폴더를 지우면 안의 디데이는 미분류로 옮겨지거나 함께 지워져 이 상태가 되지 않는다.)
      return DDayStoreClientFake(dDays: samples.dDays, photoImages: samples.photoImages)
    case .folderLoadFailed:
      // 디데이는 읽고 폴더 읽기만 한 번 실패 → 오류 화면, 다시 시도가 둘 다 다시 읽어 회복.
      return FolderFetchFailingStore(base: Self.fake(samples), failures: 1)
    case .empty:
      return DDayStoreClientFake(folders: DDayStoreClientFake.defaultFolders)
    default:
      return self.makeFailureOrPhotoStore(today: today, samples: samples)
    }
  }

  /// 불러오기·삭제 실패와 사진 시나리오의 저장소 (기본 폴더 4개).
  private func makeFailureOrPhotoStore(
    today: CalendarDay,
    samples: (dDays: [DDay], photoImages: [UUID: Data])
  ) -> any DDayStoreClient {
    switch self {
    case .loadFailed:
      // 저장소 열기 실패도 이렇게(첫 불러오기의 .loadFailed) 보인다.
      let failing = Self.fake(samples)
      failing.failNextCall(with: .loadFailed)
      return failing
    case .deleteFailed:
      return DeleteFailingStore(base: Self.fake(samples))
    case .brokenThumbnail:
      return Self.fake(ExampleSamples.samples(today: today, photos: [
        0: ExamplePhotos.broken,
        1: ExampleSamples.defaultPhotos[4] ?? ExamplePhotos.broken,
        2: ExamplePhotos.broken,
      ]))
    case .slowPhotoRead:
      return SlowPhotoStore(base: Self.fake(samples), delay: .seconds(3))
    case .photoReadFailed:
      return PhotoReadFailingStore(base: Self.fake(samples))
    case .missingLargePhoto:
      // 사진은 있지만 압축본 행이 없다: fetchPhoto 가 nil.
      return Self.fake((samples.dDays, [:]))
    case .normal, .customFolders, .noFolders, .folderLoadFailed, .empty:
      return Self.fake(samples)
    }
  }

  /// 기본 폴더 4개가 있는(열고 난 뒤의) 저장소.
  private static func fake(_ samples: (dDays: [DDay], photoImages: [UUID: Data])) -> DDayStoreClientFake {
    DDayStoreClientFake(
      dDays: samples.dDays,
      photoImages: samples.photoImages,
      folders: DDayStoreClientFake.defaultFolders
    )
  }
}

/// 실제 오늘 기준 상대 날짜로 만든 샘플. 네 그룹(다가오는·세는 중·지난·계산 불가)이 모두 나온다.
/// 일부 카드에 직접 그린 사진(썸네일·압축본)을 붙인다 (나머지는 폴더 색 기본 배경, 미분류는 기본 배경).
/// 폴더는 기본 폴더·직접 만든 폴더(`customFolders`)·없는 폴더에 나눠 둔다: 기본 폴더만 있는 저장소에서는 직접 만든 폴더와
/// 없는 폴더를 가리키는 디데이가 미분류로 보인다.
enum ExampleSamples {
  /// 직접 만든 폴더 (사용자 이름 그대로). id 는 고정.
  static let customFolders: [DDayFolder] = [
    DDayFolder(id: ExampleSamples.folderID(1), name: .custom("여행"), color: .butter, icon: .airplane),
    DDayFolder(id: ExampleSamples.folderID(2), name: .custom("시험"), color: .lavender, icon: .book),
    DDayFolder(id: ExampleSamples.folderID(3), name: .custom("덕질"), color: .blushPink, icon: .sparkles),
  ]

  /// 어느 저장소에도 없는 폴더 id (지워진 폴더를 가리키는 디데이 → 미분류).
  static let missingFolderID = ExampleSamples.folderID(99)

  /// 순서 번호 → 폴더 id. 없는 번호는 미분류.
  static let folderIDs: [Int: UUID] = {
    func system(_ folder: DefaultFolder) -> UUID? {
      DDayStoreClientFake.defaultFolders.first { $0.name == .system(folder) }?.id
    }
    let custom = ExampleSamples.customFolders.map(\.id)
    return [
      0: custom[1], // 기말고사 → 시험
      1: custom[0], // 제주 여행 → 여행 (사진)
      2: system(.birthday), // 엄마 생일
      3: system(.family), // 추석
      4: system(.couple), // 우리 만난 날 (사진)
      5: system(.other), // 새 다이어리
      6: ExampleSamples.missingFolderID, // 운동 시작 (사진) → 없는 폴더
      7: custom[0], // 방학 → 여행
      8: custom[2], // 콘서트 → 덕질
    ].compactMapValues { $0 }
  }()

  private static func folderID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-E%011d", number)) ?? UUID()
  }

  /// 순서 번호 → 사진 (기본 샘플). 한 번만 그린다.
  static let defaultPhotos: [Int: ExamplePhotos.Sample] = [
    1: ExamplePhotos.sample(.init(1, 0.78, 0.66), .init(1, 0.56, 0.69)),
    4: ExamplePhotos.sample(.init(0.66, 0.9, 0.81), .init(0.79, 0.71, 1)),
    6: ExamplePhotos.sample(.init(1, 0.91, 0.64), .init(1, 0.78, 0.66)),
  ]

  /// 샘플 디데이와 그 압축본(디데이 id → JPEG, Fake 의 `photoImages`).
  static func samples(
    today: CalendarDay,
    photos: [Int: ExamplePhotos.Sample] = ExampleSamples.defaultPhotos
  ) -> (dDays: [DDay], photoImages: [UUID: Data]) {
    let dDays = self.dDays(today: today, photos: photos.mapValues(\.photo))
    var photoImages: [UUID: Data] = [:]
    for (index, dDay) in dDays.enumerated() {
      photoImages[dDay.id] = photos[index]?.image
    }
    return (dDays, photoImages)
  }

  static func dDays(
    today: CalendarDay,
    photos: [Int: DDayPhoto] = ExampleSamples.defaultPhotos.mapValues(\.photo)
  ) -> [DDay] {
    func solar(_ offset: Int) -> DDayDate {
      .solar(today.adding(days: offset) ?? today)
    }
    let birthday = CalendarDay(year: 2000, month: 3, day: 14).map(DDayDate.solar) ?? solar(30)
    let schedules: [(String, DDaySchedule)] = [
      ("기말고사", DDaySchedule(date: solar(0))),
      ("제주 여행", DDaySchedule(date: solar(3))),
      ("엄마 생일", DDaySchedule(date: birthday, repeatRule: .yearly)),
      ("추석", DDaySchedule(date: .lunar(LunarDate(year: 2000, month: 8, day: 15)), repeatRule: .yearly)),
      ("우리 만난 날", DDaySchedule(date: solar(-100), countingStyle: .dPlus)),
      ("새 다이어리", DDaySchedule(date: solar(0), countingStyle: .dPlus)),
      ("운동 시작", DDaySchedule(date: solar(-10), countingStyle: .dayOne)),
      ("방학", DDaySchedule(date: solar(5), countingStyle: .dayOne)),
      ("콘서트", DDaySchedule(date: solar(-7))),
      ("윤달 기념일", DDaySchedule(date: .lunar(LunarDate(year: 2026, month: 6, day: 1, isLeapMonth: true)))),
    ]
    return schedules.enumerated().map { index, entry in
      let createdAt = Date(timeIntervalSince1970: TimeInterval(index))
      return DDay(
        id: UUID(),
        title: entry.0,
        schedule: entry.1,
        reminder: .default,
        createdAt: createdAt,
        updatedAt: createdAt,
        photo: photos[index],
        folderID: self.folderIDs[index]
      )
    }
  }
}
