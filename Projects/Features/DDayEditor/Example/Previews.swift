import DDayEditorFeature
import PhotoTesting
import SwiftUI

#Preview("추가") {
  @Previewable @State var model = ExampleScenario.addEmptyTitle.makePreviewModel()
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

#Preview("지원 안 되는 날짜") {
  @Previewable @State var model = ExampleScenario.unsupportedDate.makePreviewModel()
  DDayEditorView(model: model, photoPickerButton: PhotoPickerButtonFake.init)
}
