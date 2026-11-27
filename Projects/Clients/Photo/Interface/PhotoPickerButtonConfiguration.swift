import Foundation

/// 편집 화면(Feature)이 만들어 App 이 주입한 선택 버튼 View 에 넘기는 값.
/// 선택 버튼의 레이블은 Sendable 클로저 안에서 만들어지므로 Sendable 값(문구·아이콘 이름)만 둔다.
public struct PhotoPickerButtonConfiguration: Sendable {
  /// Feature 번들의 문구 ("사진 추가"/"사진 바꾸기").
  public let title: LocalizedStringResource
  /// SF Symbol 이름.
  public let systemImage: String
  /// 사진을 하나 고르면 메인 액터에서 부른다. 원본은 아직 읽지 않았다.
  public let onPicked: @MainActor @Sendable (PickedPhoto) -> Void

  public init(
    title: LocalizedStringResource,
    systemImage: String,
    onPicked: @escaping @MainActor @Sendable (PickedPhoto) -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.onPicked = onPicked
  }
}
