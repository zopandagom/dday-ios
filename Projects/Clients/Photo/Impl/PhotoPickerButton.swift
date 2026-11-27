import PhotoInterface
import PhotosUI
import SwiftUI

/// 시스템 사진 선택기(PhotosPicker)를 여는 버튼. App 이 편집 화면의 선택 버튼 슬롯에 주입한다.
/// 사진 보관함 인자를 주지 않아 선택기가 앱 밖에서 돌고 권한 요청이 없다. 고른 사진의 원본은
/// `PickedPhoto.loadData()` 를 부를 때 읽는다.
public struct PhotoPickerButton: View {
  private let configuration: PhotoPickerButtonConfiguration
  @State private var selection: PhotosPickerItem?

  public init(_ configuration: PhotoPickerButtonConfiguration) {
    self.configuration = configuration
  }

  public var body: some View {
    // 레이블 클로저는 @Sendable 이라 지역 상수만 잡는다.
    let title = self.configuration.title
    let systemImage = self.configuration.systemImage
    // HEIC 등을 변환 없이 받는다 (ImageIO 가 읽는다).
    PhotosPicker(selection: self.$selection, matching: .images, preferredItemEncoding: .current) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage)
      }
    }
    .onChange(of: self.selection) { _, item in
      guard let item else { return }
      // 같은 사진을 다시 골라도 onChange 가 오게 비운다.
      self.selection = nil
      self.configuration.onPicked(PickedPhoto { () async throws(PhotoError) -> Data in
        let data: Data?
        do {
          data = try await item.loadTransferable(type: Data.self)
        } catch {
          throw .readFailed
        }
        guard let data else { throw .readFailed }
        return data
      })
    }
  }
}
