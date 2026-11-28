import Core
import DDayStoreInterface
import DesignSystem
import SwiftUI

/// 폴더 관리 목록. 행 탭 → 수정 폼, [편집] 모드에서 끌어서 순서, 밀어서 삭제(확인창), [새 폴더].
/// 상태를 읽어 그리기만 하고 사용자 동작은 Model 의 이벤트 메서드로 넘긴다.
/// NavigationStack 과 폼 `navigationDestination` 은 App·Example 이 붙인다.
/// 편집 모드(`EditButton`)는 View 일시 상태다: 환경 `editMode` 를 읽기만 하고, Model 은 끌기 결과만 이벤트로 받는다.
public struct FolderManagerView: View {
  let model: FolderManagerModel
  @Environment(\.dismiss) private var dismiss

  public init(model: FolderManagerModel) {
    self.model = model
  }

  public var body: some View {
    FolderManagerList(model: self.model)
      .navigationTitle(Text(FolderManagerText.title))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            // 닫힘은 시트 바인딩 set(nil) 로 App 에 간다.
            self.dismiss()
          } label: {
            Text(FolderManagerText.close)
          }
          .disabled(self.model.isBusy)
        }
        ToolbarItem(placement: .primaryAction) {
          EditButton()
        }
      }
      .interactiveDismissDisabled(self.model.isBusy)
      .confirmationDialog(
        Text(FolderManagerText.deleteDialogTitle),
        isPresented: Binding(
          get: { self.model.isDeleteConfirmationPresented },
          set: { isPresented in
            if !isPresented {
              self.model.deleteConfirmationDismissed()
            }
          }
        ),
        titleVisibility: .visible,
        presenting: self.model.pendingDeletion
      ) { pending in
        // 같은 차례에 숨기도록 Task 로 감싸지 않고 바로 부른다.
        if pending.dDayCount > 0 {
          Button {
            self.model.deleteConfirmed(id: pending.folder.id, dDays: .moveToUnfiled)
          } label: {
            Text(FolderManagerText.deleteMoveToUnfiled)
          }
          Button(role: .destructive) {
            self.model.deleteConfirmed(id: pending.folder.id, dDays: .delete)
          } label: {
            Text(FolderManagerText.deleteDDays)
          }
        } else {
          // 받은 수가 오래돼 실제로 디데이가 있어도 지우지 않고 미분류로 옮긴다 (안전한 쪽).
          Button(role: .destructive) {
            self.model.deleteConfirmed(id: pending.folder.id, dDays: .moveToUnfiled)
          } label: {
            Text(FolderManagerText.delete)
          }
        }
        Button(role: .cancel) {} label: {
          Text(FolderManagerText.cancel)
        }
      } message: { pending in
        if pending.dDayCount > 0 {
          Text(FolderManagerText.deleteMessageWithDDays(pending.dDayCount))
        } else {
          Text(FolderManagerText.deleteMessageEmpty)
        }
      }
      .alert(
        Text(self.model.alert == .moveFailed ? FolderManagerText.moveFailedTitle : FolderManagerText.deleteFailedTitle),
        isPresented: Binding(
          get: { self.model.isAlertPresented },
          set: { isPresented in
            if !isPresented {
              self.model.alertDismissed()
            }
          }
        )
      ) {
        Button {} label: {
          Text(FolderManagerText.confirm)
        }
      } message: {
        Text(FolderManagerText.failedMessage)
      }
  }
}

/// 목록 부분. 환경 `editMode` 를 읽으려고 따로 둔다 (`EditButton` 이 바꾸는 환경은 툴바를 붙인 View 의 안쪽에서 보인다).
private struct FolderManagerList: View {
  let model: FolderManagerModel
  @Environment(\.editMode) private var editMode

  var body: some View {
    List {
      Section {
        if self.model.folders.isEmpty {
          Text(FolderManagerText.empty)
            .foregroundStyle(.secondary)
        } else {
          ForEach(self.model.folders) { folder in
            self.row(folder)
          }
          .onMove { offsets, destination in
            self.model.foldersMoved(fromOffsets: offsets, toOffset: destination)
          }
          .moveDisabled(self.model.isBusy)
        }
      }
      Section {
        Button {
          self.model.addButtonTapped()
        } label: {
          Label {
            Text(FolderManagerText.add)
          } icon: {
            Image(systemName: "plus")
          }
        }
        .disabled(self.model.isBusy)
      }
    }
  }

  private var isEditing: Bool {
    self.editMode?.wrappedValue.isEditing == true
  }

  private func row(_ folder: DDayFolder) -> some View {
    Button {
      self.model.folderTapped(id: folder.id)
    } label: {
      HStack {
        FolderLabel(name: folder.name, color: folder.color, icon: folder.icon)
        Spacer()
        Text(FolderManagerText.dDayCount(self.model.dDayCounts[folder.id] ?? 0))
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // 편집 모드에서는 끌기만 한다. `.disabled` 는 행의 재정렬 끌기까지 막을 수 있어 탭만 막는다
    // (재정렬 핸들은 행 내용 밖의 List 부속이라 막히지 않는다).
    .allowsHitTesting(!self.isEditing)
    // destructive 역할은 확인 전에 행이 사라지는 애니메이션을 내므로 쓰지 않는다 (확인창 뒤에 지운다).
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if !self.model.isBusy {
        Button {
          self.model.deleteSwiped(id: folder.id)
        } label: {
          Label {
            Text(FolderManagerText.delete)
          } icon: {
            Image(systemName: "trash")
          }
        }
        .tint(.red)
      }
    }
  }
}
