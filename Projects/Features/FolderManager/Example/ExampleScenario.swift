import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation

/// 시나리오의 저장소·처음 폴더 목록·디데이 수. 디데이 수는 Fake 에 실제 디데이를 넣고 그 folderID 로 센 값이다
/// (App 이 홈의 `folderDDayCounts` 를 넘기는 것과 같다. "디데이도 함께 삭제"를 Fake 로 확인할 수 있게).
struct ExampleSetup {
  let store: any DDayStoreClient
  let fake: DDayStoreClientFake
  let folders: [DDayFolder]
  let dDayCounts: [UUID: Int]
}

/// Example 앱에서 고르는 관리 화면 상태 (개발용 문구라 카탈로그 밖).
enum ExampleScenario: String, CaseIterable, Identifiable {
  case noFolders
  case defaultOnly
  case customFolders
  case saveFailed

  var id: Self { self }

  var title: String {
    switch self {
    case .noFolders: "폴더 없음"
    case .defaultOnly: "기본 폴더만 (디데이 3·0·2·1)"
    case .customFolders: "직접 만든 폴더 여럿"
    case .saveFailed: "저장 실패 (폴더 쓰기 늘 실패)"
    }
  }

  func makeSetup() -> ExampleSetup {
    switch self {
    case .noFolders:
      return Self.setup(folders: [], counts: [])
    case .defaultOnly:
      return Self.setup(folders: ExampleFolders.defaults, counts: [3, 0, 2, 1])
    case .customFolders:
      return Self.setup(folders: ExampleFolders.defaults + ExampleFolders.custom, counts: [1, 2, 0, 1, 3, 0, 2])
    case .saveFailed:
      let setup = Self.setup(folders: ExampleFolders.defaults, counts: [3, 0, 2, 1])
      return ExampleSetup(
        store: FolderWriteFailingStore(base: setup.fake),
        fake: setup.fake,
        folders: setup.folders,
        dDayCounts: setup.dDayCounts
      )
    }
  }

  /// `counts[i]` 개의 디데이를 `folders[i]` 에 넣은 Fake.
  private static func setup(folders: [DDayFolder], counts: [Int]) -> ExampleSetup {
    var dDays: [DDay] = []
    for (folder, count) in zip(folders, counts) {
      for _ in 0 ..< count {
        dDays.append(ExampleFolders.dDay(number: dDays.count + 1, folderID: folder.id))
      }
    }
    let fake = DDayStoreClientFake(dDays: dDays, folders: folders)
    var dDayCounts: [UUID: Int] = [:]
    for dDay in dDays {
      if let folderID = dDay.folderID {
        dDayCounts[folderID, default: 0] += 1
      }
    }
    return ExampleSetup(store: fake, fake: fake, folders: folders, dDayCounts: dDayCounts)
  }
}

/// 직접 만든 샘플 폴더·디데이.
enum ExampleFolders {
  static let defaults = DDayStoreClientFake.defaultFolders

  static let custom: [DDayFolder] = [
    DDayFolder(id: ExampleFolders.id(101), name: .custom("여행"), color: .mint, icon: .airplane),
    DDayFolder(id: ExampleFolders.id(102), name: .custom("시험"), color: .butter, icon: .book),
    DDayFolder(id: ExampleFolders.id(103), name: .custom("덕질"), color: .lavender, icon: .sparkles),
  ]

  /// 고정 id (Example 이라 강제 언래핑 대신 빈 값이면 새 UUID).
  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
  }

  static func dDay(number: Int, folderID: UUID) -> DDay {
    let createdAt = Date(timeIntervalSince1970: TimeInterval(number * 60))
    let day = CalendarDay(year: 2027, month: 1, day: min(number, 28)) ?? CalendarDay(Date(), in: .current)
    return DDay(
      id: self.id(1000 + number),
      title: "디데이 \(number)",
      schedule: DDaySchedule(date: .solar(day), repeatRule: .none, countingStyle: .dDay),
      reminder: .default,
      createdAt: createdAt,
      updatedAt: createdAt,
      photo: nil,
      folderID: folderID
    )
  }
}
