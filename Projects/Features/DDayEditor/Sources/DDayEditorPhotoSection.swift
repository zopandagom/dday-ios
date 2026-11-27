import PhotoInterface
import SwiftUI

/// 편집 화면의 사진 섹션: 미리보기, 선택 버튼(App 이 주입) 또는 불러오는 중 + [취소], [사진 지우기], 안내 footer.
struct DDayEditorPhotoSection<PickerButton: View>: View {
  let model: DDayEditorModel
  let photoPickerButton: @MainActor (PhotoPickerButtonConfiguration) -> PickerButton

  var body: some View {
    Section {
      EditorThumbnailImage(data: self.model.photoPreviewThumbnail)
        .listRowInsets(EdgeInsets())

      if self.model.photoStep == .loading {
        HStack(spacing: 12) {
          ProgressView()
          Text(DDayEditorText.photoLoading)
            .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          Button {
            self.model.photoLoadingCancelled()
          } label: {
            Text(DDayEditorText.cancel)
          }
        }
      } else {
        self.photoPickerButton(self.configuration)
          .disabled(!self.model.canPickPhoto)
      }

      if self.model.hasPhoto {
        Button(role: .destructive) {
          self.model.photoRemoveTapped()
        } label: {
          Text(DDayEditorText.photoRemove)
        }
        .disabled(!self.model.canPickPhoto)
      }
    } header: {
      Text(DDayEditorText.photoSection)
    } footer: {
      Text(DDayEditorText.photoFooter(self.model.photoNotice))
    }
  }

  /// 선택 버튼에 넘기는 값. 사진을 고르면 Model 의 `photoPicked(_:)` 로 넘긴다.
  private var configuration: PhotoPickerButtonConfiguration {
    let model = self.model
    return PhotoPickerButtonConfiguration(
      title: model.hasPhoto ? DDayEditorText.photoChange : DDayEditorText.photoAdd,
      systemImage: "photo.on.rectangle",
      onPicked: { picked in
        model.photoPicked(picked)
      }
    )
  }
}
