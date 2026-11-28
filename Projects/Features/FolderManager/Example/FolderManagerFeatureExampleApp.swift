import Core
import DDayStoreInterface
import DDayStoreTesting
import FolderManagerFeature
import Foundation
import Observation
import SwiftUI

/// App 없이 폴더 관리 화면만 띄우는 데모 앱. 시나리오를 고르면 App 과 같은 방식(시트 안 NavigationStack + 관리 화면 +
/// 폼 push)으로 띄우고, 받은 콜백(폴더 순서·이름, 지운 디데이 수)을 "마지막 콜백" 섹션에 보인다.
/// 흐름은 `ExampleFlow` (App `AppFlow` 의 관리 시트 부분과 같은 규칙).
@main
struct FolderManagerFeatureExampleApp: App {
  @State private var flow = ExampleFlow()

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          Section("마지막 콜백") {
            Text(self.flow.lastFolders)
            Text("지운 디데이 수: \(self.flow.deletedDDayCount)")
            Text("저장소 디데이 수: \(self.flow.storedDDayCount.map(String.init) ?? "-")")
          }
          Section("시나리오") {
            ForEach(ExampleScenario.allCases) { scenario in
              Button(scenario.title) {
                self.flow.open(scenario)
              }
            }
          }
        }
        .navigationTitle("FolderManager 예제")
        .sheet(item: Binding(
          get: { self.flow.manager },
          set: { session in
            if session == nil {
              self.flow.managerDismissed()
            }
          }
        )) { session in
          NavigationStack {
            FolderManagerView(model: session.model)
              .navigationDestination(item: Binding(
                get: { self.flow.form },
                set: { form in
                  if form == nil {
                    self.flow.formDismissed()
                  }
                }
              )) { form in
                FolderFormView(model: form.model)
              }
          }
        }
      }
    }
  }
}

struct ExampleManagerSession: Identifiable {
  let id: UUID
  let model: FolderManagerModel
}

/// `==`·`hash` 는 id 만 본다.
struct ExampleFormSession: Identifiable, Hashable {
  let id: UUID
  let model: FolderFormModel

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

/// 예제 흐름 (App `AppFlow` 의 관리 시트 부분과 같은 규칙: 열고 닫는 판단은 `FolderManagerPresentation`, 폼 세션 하나,
/// 폼 결과는 관리 모델에 `formFinished`, 늦은 결과도 넘긴다). 편집 시트는 없다.
@MainActor
@Observable
final class ExampleFlow {
  private(set) var manager: ExampleManagerSession?
  private(set) var form: ExampleFormSession?
  private(set) var lastFolders = "없음"
  private(set) var deletedDDayCount = 0
  private(set) var storedDDayCount: Int?

  @ObservationIgnored private var presentation = FolderManagerPresentation()
  @ObservationIgnored private var lastManagerModel: FolderManagerModel?
  @ObservationIgnored private var lastFormModel: FolderFormModel?

  func open(_ scenario: ExampleScenario) {
    let isPreviousWorkInFlight = self.lastManagerModel?.isBusy == true || self.lastFormModel?.phase == .saving
    guard let sessionID = self.presentation.open(
      newID: UUID(),
      isEditorPresented: false,
      isPreviousWorkInFlight: isPreviousWorkInFlight
    ) else { return }
    let setup = scenario.makeSetup()
    let fake = setup.fake
    let reference = WeakManagerReference()
    let model = FolderManagerModel(
      folders: setup.folders,
      dDayCounts: setup.dDayCounts,
      store: setup.store,
      onAddTapped: { [weak self] in
        guard let manager = reference.model else { return }
        self?.openForm(.add, store: setup.store, managerSessionID: sessionID, manager: manager)
      },
      onEditTapped: { [weak self] folder in
        guard let manager = reference.model else { return }
        self?.openForm(.edit(folder), store: setup.store, managerSessionID: sessionID, manager: manager)
      },
      onFoldersChanged: { [weak self] folders in
        self?.lastFolders = "폴더 \(folders.count)개: " + folders.map(Self.nameText).joined(separator: ", ")
        self?.storedDDayCount = fake.dDays.count
      },
      onDDayDeleted: { [weak self] _ in
        self?.deletedDDayCount += 1
      }
    )
    reference.model = model
    self.lastManagerModel = model
    self.deletedDDayCount = 0
    self.lastFolders = "없음"
    self.storedDDayCount = fake.dDays.count
    self.manager = ExampleManagerSession(id: sessionID, model: model)
  }

  func managerDismissed() {
    guard self.presentation.dismissed() != nil else { return }
    self.manager = nil
    self.form = nil
  }

  func formDismissed() {
    guard self.presentation.formDismissed() != nil else { return }
    self.form = nil
  }

  private func openForm(
    _ mode: FolderFormMode,
    store: any DDayStoreClient,
    managerSessionID: UUID,
    manager: FolderManagerModel
  ) {
    guard let formID = self.presentation.openForm(newID: UUID(), managerSessionID: managerSessionID) else { return }
    let model = FolderFormModel(mode: mode, store: store) { [weak self] outcome in
      if self?.presentation.formFinished(formSessionID: formID) == true {
        self?.form = nil
      }
      manager.formFinished(outcome)
    }
    self.lastFormModel = model
    self.form = ExampleFormSession(id: formID, model: model)
  }

  /// 콜백 줄의 폴더 이름 (개발용): 기본 폴더 키·사용자 이름.
  private static func nameText(_ folder: DDayFolder) -> String {
    switch folder.name {
    case let .system(key): key.rawValue
    case let .custom(name): name
    }
  }
}

@MainActor
private final class WeakManagerReference {
  weak var model: FolderManagerModel?
}
