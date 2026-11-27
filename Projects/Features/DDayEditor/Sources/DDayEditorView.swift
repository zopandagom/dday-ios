import Core
import DDayStoreInterface
import DesignSystem
import PhotoInterface
import SwiftUI

/// 디데이 추가·수정 화면 (시트 내용 전체, 자기 NavigationStack 포함).
/// 상태를 읽어 그리기만 하고, 사용자 동작은 Model 의 이벤트 메서드로 넘긴다.
/// 사진 선택 버튼은 App(실제 PhotosPicker)·Example(Fake)이 `photoPickerButton` 으로 주입한다 (Feature 는 PhotosUI 를 쓰지 않는다).
/// 자르기 화면은 시트 안 내비게이션 push 다 (선택기 시트가 내려가는 중에도 모달 표시가 겹치지 않게).
public struct DDayEditorView<PickerButton: View>: View {
  let model: DDayEditorModel
  let photoPickerButton: @MainActor (PhotoPickerButtonConfiguration) -> PickerButton

  public init(
    model: DDayEditorModel,
    photoPickerButton: @escaping @MainActor (PhotoPickerButtonConfiguration) -> PickerButton
  ) {
    self.model = model
    self.photoPickerButton = photoPickerButton
  }

  public var body: some View {
    NavigationStack {
      Form {
        DDayEditorPhotoSection(model: self.model, photoPickerButton: self.photoPickerButton)
        self.titleSection
        // 폴더 목록이 없으면(홈 불러오기 전·실패) 섹션을 숨기고 미분류로 저장한다.
        if !self.model.folders.isEmpty {
          self.folderSection
        }
        DDayEditorDateSection(model: self.model)
        self.repeatSection
        self.countingSection
        DDayEditorReminderSection(model: self.model)
        if self.model.reminderIsEnabled, self.model.showsMilestoneReminders {
          DDayEditorMilestoneSection(model: self.model)
        }
        if self.model.isEditingExisting {
          self.deleteSection
        }
      }
      .disabled(self.model.isBusy)
      .navigationTitle(Text(self.model.isAddMode ? DDayEditorText.addTitle : DDayEditorText.editTitle))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { self.toolbar }
      .navigationDestination(isPresented: Binding(
        get: { self.model.isCropPresented },
        set: { isPresented in
          // 버리기 확인창 때문에 잠시 내린 것이면 작업 이미지를 버리지 않는다 (Model 도 무시한다).
          if !isPresented, !self.model.isDiscardConfirmationPresented {
            self.model.cropCancelled()
          }
        }
      )) {
        DDayEditorCropView(model: self.model)
      }
      .confirmationDialog(
        Text(DDayEditorText.discardTitle),
        isPresented: Binding(
          get: { self.model.isDiscardConfirmationPresented },
          set: { isPresented in
            if !isPresented {
              self.model.discardConfirmationDismissed()
            }
          }
        ),
        titleVisibility: .visible
      ) {
        Button(role: .destructive) {
          self.model.discardConfirmed()
        } label: {
          Text(DDayEditorText.discardAction)
        }
        // 닫힘은 바인딩 set(false) 로만 받는다.
        Button(role: .cancel) {} label: {
          Text(DDayEditorText.keepEditing)
        }
      }
      .alert(
        Text(DDayEditorText.alertTitle(self.model.alert)),
        isPresented: Binding(
          get: { self.model.isAlertPresented },
          set: { isPresented in
            if !isPresented {
              self.model.alertDismissed()
            }
          }
        ),
        presenting: self.model.alert
      ) { kind in
        switch kind {
        case .notFoundOnSave:
          // 같은 차례에 저장을 시작하도록 Task 로 감싸지 않고 바로 부른다.
          Button {
            self.model.saveAsNewTapped()
          } label: {
            Text(DDayEditorText.saveAsNew)
          }
          Button(role: .cancel) {} label: {
            Text(DDayEditorText.cancel)
          }
        case .saveFailed, .deleteFailed:
          Button(role: .cancel) {} label: {
            Text(DDayEditorText.confirm)
          }
        }
      } message: { kind in
        Text(DDayEditorText.alertMessage(kind, isStoredPhotoLost: self.model.isPhotoLostMessageShown))
      }
    }
    .interactiveDismissDisabled(self.model.isDismissDisabled)
  }

  // MARK: - 툴바

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button {
        self.model.cancelButtonTapped()
      } label: {
        Text(DDayEditorText.cancel)
      }
      .disabled(self.model.isBusy)
    }
    ToolbarItem(placement: .confirmationAction) {
      if self.model.phase == .saving {
        ProgressView()
      } else {
        // 같은 차례에 저장 중이 되도록 Task 로 감싸지 않고 바로 부른다.
        Button {
          self.model.saveButtonTapped()
        } label: {
          Text(DDayEditorText.save)
        }
        .disabled(!self.model.canSave)
      }
    }
  }

  // MARK: - 제목

  private var titleSection: some View {
    Section {
      TextField(text: Binding(get: { self.model.title }, set: { self.model.titleChanged($0) })) {
        Text(DDayEditorText.fieldTitle)
      }
    } footer: {
      if self.model.isTitleEmpty {
        Text(DDayEditorText.titleEmpty)
      }
    }
  }

  // MARK: - 폴더

  /// 메뉴 Picker (시트 안 자르기 push 와 내비게이션 방식이 섞이지 않게 `.navigationLink` 스타일은 쓰지 않는다).
  private var folderSection: some View {
    Section {
      Picker(selection: Binding(get: { self.model.folderID }, set: { self.model.folderChanged($0) })) {
        FolderLabel.unfiled.tag(UUID?.none)
        ForEach(self.model.folders) { folder in
          FolderLabel(name: folder.name, color: folder.color, icon: folder.icon).tag(Optional(folder.id))
        }
      } label: {
        Text(DDayEditorText.folderSection)
      }
    }
  }

  // MARK: - 반복·세는 방식

  private var repeatSection: some View {
    Section {
      Picker(selection: Binding(get: { self.model.repeatRule }, set: { self.model.repeatRuleChanged($0) })) {
        ForEach(RepeatRule.allCases, id: \.self) { rule in
          Text(DDayEditorText.repeatRule(rule)).tag(rule)
        }
      } label: {
        Text(DDayEditorText.repeatSection)
      }
    }
  }

  private var countingSection: some View {
    Section {
      Picker(selection: Binding(
        get: { self.model.countingStyle },
        set: { self.model.countingStyleChanged($0) }
      )) {
        ForEach(CountingStyle.allCases, id: \.self) { style in
          Text(DDayEditorText.counting(style)).tag(style)
        }
      } label: {
        Text(DDayEditorText.countingSection)
      }
    }
  }

  // MARK: - 삭제

  private var deleteSection: some View {
    Section {
      Button(role: .destructive) {
        self.model.deleteButtonTapped()
      } label: {
        Text(DDayEditorText.delete)
      }
      // 사진 처리 중에는 삭제하지 않는다 (Model 도 무시한다).
      .disabled(self.model.isPhotoBusy)
      .confirmationDialog(
        Text(DDayEditorText.deleteConfirmTitle),
        isPresented: Binding(
          get: { self.model.isDeleteConfirmationPresented },
          set: { isPresented in
            if !isPresented {
              self.model.deleteConfirmationDismissed()
            }
          }
        ),
        titleVisibility: .visible
      ) {
        // 같은 차례에 삭제 중이 되도록 Task 로 감싸지 않고 바로 부른다.
        Button(role: .destructive) {
          self.model.deleteConfirmed()
        } label: {
          Text(DDayEditorText.deleteConfirmAction)
        }
        Button(role: .cancel) {} label: {
          Text(DDayEditorText.cancel)
        }
      }
    }
  }
}
