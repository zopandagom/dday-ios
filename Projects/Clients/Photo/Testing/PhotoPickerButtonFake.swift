import PhotoInterface
import SwiftUI

/// Example 용 사진 선택 버튼. 시스템 선택기 대신 메뉴로 샘플 사진이나 읽기 실패를 고른다.
/// 메뉴 항목 문구는 개발용이라 하드코딩한다 (PRODUCT §3 예외: Example 개발용 문구).
public struct PhotoPickerButtonFake: View {
  private let configuration: PhotoPickerButtonConfiguration

  public init(_ configuration: PhotoPickerButtonConfiguration) {
    self.configuration = configuration
  }

  public var body: some View {
    Menu {
      Button {
        self.configuration.onPicked(PickedPhoto { PhotoSamples.jpegData(width: 4000, height: 3000) })
      } label: {
        Text(verbatim: "샘플 사진 (가로 4000×3000)")
      }
      Button {
        self.configuration.onPicked(PickedPhoto { PhotoSamples.jpegData(width: 4000, height: 3000, orientation: 6) })
      } label: {
        Text(verbatim: "샘플 사진 (세로, 방향 6)")
      }
      Button {
        self.configuration.onPicked(PickedPhoto { () async throws(PhotoError) -> Data in throw .readFailed })
      } label: {
        Text(verbatim: "읽기 실패")
      }
    } label: {
      Label {
        Text(self.configuration.title)
      } icon: {
        Image(systemName: self.configuration.systemImage)
      }
    }
  }
}
