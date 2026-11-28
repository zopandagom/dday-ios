import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
@testable import FolderManagerFeature

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다.
enum FolderSample {
  static func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
  }

  /// Fake 기본 폴더 (생일·가족·연인·기타 순서).
  static let defaults = DDayStoreClientFake.defaultFolders
  static var birthday: DDayFolder { FolderSample.defaults[0] }
  static var family: DDayFolder { FolderSample.defaults[1] }
  static var couple: DDayFolder { FolderSample.defaults[2] }
  static var other: DDayFolder { FolderSample.defaults[3] }

  /// 직접 만든 폴더.
  static let travel = DDayFolder(id: FolderSample.id(501), name: .custom("여행"), color: .mint, icon: .airplane)

  /// 테스트용 기본 이름 (앱 언어와 무관하게 고정).
  static func systemName(_ folder: DefaultFolder) -> String {
    switch folder {
    case .birthday: "생일"
    case .family: "가족"
    case .couple: "연인"
    case .other: "기타"
    }
  }

  /// 그 폴더에 든 디데이 (id 는 `number`).
  static func dDay(_ number: Int, folderID: UUID?) -> DDay {
    let createdAt = Date(timeIntervalSince1970: TimeInterval(number * 10))
    return DDay(
      id: self.id(number),
      title: "디데이 \(number)",
      schedule: DDaySchedule(
        date: .solar(CalendarDay(year: 2026, month: 12, day: 1)!),
        repeatRule: .none,
        countingStyle: .dDay
      ),
      reminder: .default,
      createdAt: createdAt,
      updatedAt: createdAt,
      photo: nil,
      folderID: folderID
    )
  }
}

/// 관리 모델 콜백을 부른 순서대로 남긴다.
@MainActor
final class CallbackRecorder {
  enum Event: Equatable {
    case added
    case edit(DDayFolder)
    case foldersChanged([DDayFolder])
    case dDayDeleted(UUID)
  }

  var events: [Event] = []

  func makeManager(
    folders: [DDayFolder] = FolderSample.defaults,
    dDayCounts: [UUID: Int] = [:],
    store: any DDayStoreClient
  ) -> FolderManagerModel {
    FolderManagerModel(
      folders: folders,
      dDayCounts: dDayCounts,
      store: store,
      onAddTapped: { self.events.append(.added) },
      onEditTapped: { self.events.append(.edit($0)) },
      onFoldersChanged: { self.events.append(.foldersChanged($0)) },
      onDDayDeleted: { self.events.append(.dDayDeleted($0)) }
    )
  }
}

/// 폼 결과를 남긴다.
@MainActor
final class FormRecorder {
  var outcomes: [FolderFormOutcome] = []

  func makeForm(_ mode: FolderFormMode, store: any DDayStoreClient) -> FolderFormModel {
    FolderFormModel(
      mode: mode,
      store: store,
      systemName: FolderSample.systemName,
      onFinished: { self.outcomes.append($0) }
    )
  }
}
