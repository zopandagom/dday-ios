import DDayEditorFeature
import PhotoTesting
import SwiftUI

#Preview("추가") {
  @Previewable @State var model = ExampleScenario.addEmptyTitle.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("추가 (가족 칩에서 열림)") {
  @Previewable @State var model = ExampleScenario.addInFolder.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("수정 (연인 폴더)") {
  @Previewable @State var model = ExampleScenario.editWithFolder.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("폴더 없음 (섹션 숨김)") {
  @Previewable @State var model = ExampleScenario.noFolders.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("수정(사진 있음)") {
  @Previewable @State var model = ExampleScenario.editWithPhoto.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("수정(음력 윤달)") {
  @Previewable @State var model = ExampleScenario.editLunarLeap.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("D+ 기념일 알림") {
  @Previewable @State var model = ExampleScenario.dPlusReminder.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("알림 거부 안내") {
  @Previewable @State var model = ExampleScenario.notificationDenied.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}

#Preview("지원 안 되는 날짜") {
  @Previewable @State var model = ExampleScenario.unsupportedDate.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}
