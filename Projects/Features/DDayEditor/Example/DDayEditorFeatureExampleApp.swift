import Core
import DDayEditorFeature
import DDayStoreTesting
import Foundation
import Observation
import PhotoTesting
import SwiftUI

/// App 없이 편집 화면만 띄우는 데모 앱. 시나리오를 고르면 App 과 같은 방식(sheet(item:))으로 시트를 띄우고,
/// 끝나면 마지막 결과와 Fake 저장소의 디데이 수를 목록 위에 보인다. 끌어내려 닫은 뒤 늦게 끝난 옛 편집의 결과도
/// 결과 줄에 보이고, 그 사이 새로 연 시트는 닫지 않는다. 사진 선택 버튼은 Fake(`PhotoPickerButtonFake`)를 주입한다.
/// 폴더 목록·추가 기본 폴더는 시나리오가 정하고(App 이 홈의 목록·칩을 넘기는 것과 같다), 결과 줄에 저장된 폴더를 보인다.
/// 알림 권한 거부 여부도 시나리오가 정하고, [설정 열기] 는 설정 앱을 열지 않고 누른 횟수만 목록 위에 보인다.
@main
struct DDayEditorFeatureExampleApp: App {
  @State private var state = ExampleState()

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          Section("마지막 결과") {
            Text(self.state.lastOutcome)
            Text("저장된 디데이 수: \(self.state.storedCount.map(String.init) ?? "-")")
            Text("저장된 사진 수: \(self.state.storedPhotoCount.map(String.init) ?? "-")")
            Text("설정 열기 누른 수: \(String(self.state.settingsTapCount))")
          }
          Section("시나리오") {
            ForEach(ExampleScenario.allCases) { scenario in
              Button(scenario.title) {
                self.state.open(scenario)
              }
            }
          }
        }
        .navigationTitle("DDayEditor 예제")
      }
      .sheet(item: Binding(
        get: { self.state.session },
        set: { session in
          if session == nil {
            self.state.sheetDismissed()
          }
        }
      )) { session in
        DDayEditorView(model: session.model, photoPickerButton: PhotoPickerButtonFake.init)
      }
    }
  }
}

/// 띄운 편집 화면 하나.
struct ExampleSession: Identifiable {
  let id: UUID
  let model: DDayEditorModel
}

/// 예제 화면 흐름 (App 의 AppFlow 와 같은 방식: 띄우고 닫는 판단은 `DDayEditorPresentation`).
@MainActor
@Observable
final class ExampleState {
  private(set) var session: ExampleSession?
  private(set) var lastOutcome = "없음"
  private(set) var storedCount: Int?
  private(set) var storedPhotoCount: Int?
  private(set) var settingsTapCount = 0
  @ObservationIgnored private var presentation = DDayEditorPresentation()

  func open(_ scenario: ExampleScenario) {
    guard let id = self.presentation.open(newID: UUID()) else { return }
    let setup = scenario.makeSetup()
    let fake = setup.fake
    let model = DDayEditorModel(
      mode: setup.mode,
      store: setup.store,
      photoClient: setup.photoClient,
      today: CalendarDay(Date(), in: .autoupdatingCurrent),
      folders: setup.folders,
      defaultFolderID: setup.defaultFolderID,
      isNotificationDenied: setup.isNotificationDenied,
      onNotificationSettingsTapped: { [weak self] in
        self?.settingsTapCount += 1
      },
      onFinished: { [weak self] outcome in
        self?.finished(outcome, sessionID: id, fake: fake)
      }
    )
    self.storedCount = fake.dDays.count
    self.storedPhotoCount = fake.photoImages.count
    self.session = ExampleSession(id: id, model: model)
  }

  /// 시트 바인딩 set(nil): 먼저 세션을 내리고 모델에 알린다.
  func sheetDismissed() {
    guard self.presentation.dismissed() != nil, let session = self.session else { return }
    self.session = nil
    session.model.sheetDismissed()
  }

  /// 늦게 끝난 옛 세션도 결과 줄·디데이 수는 갱신한다 (떠 있는 새 시트는 닫지 않는다).
  private func finished(_ outcome: DDayEditorOutcome, sessionID: UUID, fake: DDayStoreClientFake) {
    if self.presentation.finished(sessionID: sessionID) {
      self.session = nil
    }
    self.lastOutcome = switch outcome {
    case let .saved(dDay):
      "saved: \(dDay.title) (\(dDay.id.uuidString.prefix(8))), 폴더 \(Self.folderText(dDay.folderID, in: fake))"
    case let .savedAsNew(dDay, original):
      "savedAsNew: \(dDay.title) (\(dDay.id.uuidString.prefix(8))), replacing \(original.uuidString.prefix(8)), "
        + "폴더 \(Self.folderText(dDay.folderID, in: fake))"
    case let .deleted(id): "deleted: \(id.uuidString.prefix(8))"
    case .cancelled: "cancelled"
    }
    self.storedCount = fake.dDays.count
    self.storedPhotoCount = fake.photoImages.count
  }

  /// 결과 줄의 폴더 (개발용 문구라 카탈로그 밖): 기본 폴더 키·사용자 이름, 없으면 "미분류".
  private static func folderText(_ folderID: UUID?, in fake: DDayStoreClientFake) -> String {
    switch fake.folders.first(where: { $0.id == folderID })?.name {
    case let .system(folder): folder.rawValue
    case let .custom(name): name
    case nil: "미분류"
    }
  }
}
