import Core
import DesignSystem
import SwiftUI

/// 폴더 추가·수정 폼 (관리 시트 안 push). 이름·색 5·아이콘 12. 상태를 읽어 그리기만 하고 입력은 이벤트로 넘긴다.
/// 저장 중에는 뒤로 가기와 시트 끌어내림을 막는다.
public struct FolderFormView: View {
  let model: FolderFormModel

  private static let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

  public init(model: FolderFormModel) {
    self.model = model
  }

  public var body: some View {
    Form {
      Section {
        self.preview
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowBackground(Color.clear)
      }
      Section {
        TextField(
          text: Binding(
            get: { self.model.nameText },
            set: { self.model.nameChanged($0) }
          )
        ) {
          Text(FolderManagerText.namePlaceholder)
        }
      } header: {
        Text(FolderManagerText.formName)
      } footer: {
        if self.model.nameValidation == .tooLong {
          Text(FolderManagerText.nameTooLong(FolderNameRule.maxLength))
            .foregroundStyle(.red)
        } else {
          Text(FolderManagerText.nameLength(self.model.nameLength, FolderNameRule.maxLength))
        }
      }
      Section {
        HStack {
          ForEach(FolderColor.allCases, id: \.self) { color in
            self.colorButton(color)
            if color != FolderColor.allCases.last {
              Spacer(minLength: 0)
            }
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text(FolderManagerText.formColor)
      }
      Section {
        LazyVGrid(columns: Self.iconColumns, spacing: 12) {
          ForEach(FolderIcon.allCases, id: \.self) { icon in
            self.iconButton(icon)
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text(FolderManagerText.formIcon)
      }
    }
    .navigationTitle(Text(self.isAdd ? FolderManagerText.formAddTitle : FolderManagerText.formEditTitle))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        if self.model.phase == .saving {
          ProgressView()
        } else {
          Button {
            self.model.saveButtonTapped()
          } label: {
            Text(FolderManagerText.formSave)
          }
          .disabled(!self.model.canSave)
        }
      }
    }
    .navigationBarBackButtonHidden(self.model.phase == .saving)
    .interactiveDismissDisabled(self.model.phase == .saving)
    .alert(
      Text(FolderManagerText.saveFailedTitle),
      isPresented: Binding(
        get: { self.model.isSaveFailedAlertPresented },
        set: { isPresented in
          if !isPresented {
            self.model.saveFailedAlertDismissed()
          }
        }
      )
    ) {
      Button {} label: {
        Text(FolderManagerText.formConfirm)
      }
    } message: {
      Text(FolderManagerText.saveFailedMessage)
    }
  }

  private var isAdd: Bool {
    self.model.mode == .add
  }

  /// 저장될 모습 미리보기. 이름이 비면 자리 표시 문구.
  @ViewBuilder
  private var preview: some View {
    let name = FolderNameRule.normalized(self.model.nameText)
    FolderChip(
      title: name.isEmpty ? Text(FolderManagerText.namePlaceholder) : Text(verbatim: name),
      color: self.model.color,
      icon: self.model.icon,
      isSelected: true
    ) {}
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  private func colorButton(_ color: FolderColor) -> some View {
    let isSelected = self.model.color == color
    return Button {
      self.model.colorSelected(color)
    } label: {
      Circle()
        .fill(color.color)
        .frame(width: 40, height: 40)
        .overlay {
          if isSelected {
            Image(systemName: "checkmark")
              .font(.body.weight(.bold))
              .foregroundStyle(.primary)
          }
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(FolderManagerText.colorName(color)))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private func iconButton(_ icon: FolderIcon) -> some View {
    let isSelected = self.model.icon == icon
    return Button {
      self.model.iconSelected(icon)
    } label: {
      icon.image
        .font(.title3)
        .foregroundStyle(.primary)
        .frame(width: 44, height: 44)
        .background(Circle().fill(isSelected ? self.model.color.color : Color(.secondarySystemFill)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(FolderManagerText.iconName(icon)))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
