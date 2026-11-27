import Core
import DDayStoreInterface
import DDayStoreTesting
import FolderManagerFeature
import SwiftUI

@MainActor
private func previewManager(_ scenario: ExampleScenario) -> FolderManagerModel {
  let setup = scenario.makeSetup()
  return FolderManagerModel(
    folders: setup.folders,
    dDayCounts: setup.dDayCounts,
    store: setup.store,
    onAddTapped: {},
    onEditTapped: { _ in },
    onFoldersChanged: { _ in },
    onDDayDeleted: { _ in }
  )
}

@MainActor
private func previewForm(_ mode: FolderFormMode, name: String? = nil) -> FolderFormModel {
  let model = FolderFormModel(
    mode: mode,
    store: DDayStoreClientFake(folders: ExampleFolders.defaults),
    onFinished: { _ in }
  )
  if let name {
    model.nameChanged(name)
  }
  return model
}

#Preview("관리 (기본 폴더만)") {
  NavigationStack {
    FolderManagerView(model: previewManager(.defaultOnly))
  }
}

#Preview("관리 (직접 만든 폴더 여럿)") {
  NavigationStack {
    FolderManagerView(model: previewManager(.customFolders))
  }
}

#Preview("관리 (폴더 없음)") {
  NavigationStack {
    FolderManagerView(model: previewManager(.noFolders))
  }
}

#Preview("폼 추가") {
  NavigationStack {
    FolderFormView(model: previewForm(.add))
  }
}

#Preview("폼 수정 (기본 폴더)") {
  NavigationStack {
    FolderFormView(model: previewForm(.edit(ExampleFolders.defaults[0])))
  }
}

#Preview("폼 수정 (21자 이름)") {
  NavigationStack {
    FolderFormView(model: previewForm(.edit(ExampleFolders.custom[0]), name: String(repeating: "가", count: 21)))
  }
}
