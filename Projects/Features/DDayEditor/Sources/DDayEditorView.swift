import Core
import DDayStoreInterface
import SwiftUI

/// 디데이 추가·수정 화면 (시트 내용 전체, 자기 NavigationStack 포함).
/// 상태를 읽어 그리기만 하고, 사용자 동작은 Model 의 이벤트 메서드로 넘긴다.
public struct DDayEditorView: View {
  let model: DDayEditorModel

  public init(model: DDayEditorModel) {
    self.model = model
  }

  public var body: some View {
    NavigationStack {
      Form {
        self.titleSection
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
        Text(DDayEditorText.alertMessage(kind))
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
