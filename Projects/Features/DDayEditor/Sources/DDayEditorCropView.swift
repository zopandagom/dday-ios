import Core
import PhotoInterface
import SwiftUI

/// 3:2 자르기 화면 (편집 시트 안 내비게이션 push). 끌어서 옮기고 두 손가락으로 확대한다.
/// 제스처 중 영역은 `PhotoCropGeometry.crop(zoom:center:)` 로 계속 클램프하고, 끝나면 확대·중심을 View 일시 상태에 둔다.
/// 끌기와 확대는 한 제스처(`simultaneously`)의 한 값(`CropGesture`)으로 그리고 확정한다. 두 손가락을 함께 떼도
/// `onEnded` 순서에 기대지 않고, 손을 떼기 직전에 보인 영역 그대로 확정된다. 부분 제스처가 끝나거나 다시 시작될 때의
/// 규칙과 영역 계산은 `CropGesture`(순수 값, 테스트 있음)에 있다.
/// [완료] 는 그 영역을 Model 의 `cropConfirmed(_:)` 로 넘긴다. 만드는 중에는 버튼·제스처가 막힌다.
struct DDayEditorCropView: View {
  let model: DDayEditorModel
  @State private var committed = CropGesture.Committed(zoom: 1, center: CGPoint(x: 0.5, y: 0.5))
  @GestureState private var live = CropGesture()
  /// `updating` 이 마지막으로 반영한 값. `onEnded` 가 확정에 쓴다 (`@GestureState` 초기화 시점에 기대지 않으려고).
  /// 화면에 쓰지 않는 값이라 관찰하지 않는 참조 상자에 둔다. 취소된 제스처의 값이 남아도 다음 제스처의 첫
  /// `updating` 이 덮는다 (`@GestureState` 가 초기값에서 다시 시작하므로).
  @State private var lastLive = CropGestureBox()

  @MainActor
  private final class CropGestureBox {
    var value = CropGesture()
  }

  var body: some View {
    VStack(spacing: 16) {
      if let image = self.model.cropImage, let geometry = image.geometry {
        self.cropFrame(image: image, geometry: geometry)
      }
      Text(DDayEditorText.cropHint)
        .font(.footnote)
        .foregroundStyle(.secondary)
      if self.model.photoNotice == .renderFailed {
        Text(DDayEditorText.cropRenderFailed)
          .font(.footnote)
          .foregroundStyle(.red)
      }
      Spacer(minLength: 0)
    }
    .padding()
    .navigationTitle(Text(DDayEditorText.cropTitle))
    .navigationBarTitleDisplayMode(.inline)
    // 뒤로 가기(스와이프 포함)를 막고 [취소] 로만 돌아간다.
    .navigationBarBackButtonHidden(true)
    .toolbar { self.toolbar }
  }

  // MARK: - 툴바

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button {
        self.model.cropCancelled()
      } label: {
        Text(DDayEditorText.cancel)
      }
      .disabled(self.model.isRendering)
    }
    ToolbarItem(placement: .confirmationAction) {
      if self.model.isRendering {
        ProgressView()
      } else {
        // 같은 차례에 만드는 중이 되도록 Task 로 감싸지 않고 바로 부른다.
        Button {
          guard let geometry = self.model.cropImage?.geometry else { return }
          self.model.cropConfirmed(geometry.crop(zoom: self.committed.zoom, center: self.committed.center))
        } label: {
          Text(DDayEditorText.cropDone)
        }
        // 끌기·확대 중에는 막는다: [완료] 는 확정된 zoom·center 로 만들므로, 진행 중이면 보이는 영역과 달라진다.
        .disabled(self.live != CropGesture())
      }
    }
  }

  // MARK: - 자르기 틀

  private func cropFrame(image: PhotoWorkingImage, geometry: PhotoCropGeometry) -> some View {
    GeometryReader { proxy in
      let frameWidth = proxy.size.width
      let crop = self.live.crop(geometry, frameWidth: frameWidth, committed: self.committed)
      let size = CropGesture.displaySize(geometry, crop: crop, frameWidth: frameWidth)
      Image(decorative: image.image, scale: 1)
        .resizable()
        .frame(width: size.width, height: size.height)
        .offset(x: -crop.minX * size.width, y: -crop.minY * size.height)
        .frame(width: frameWidth, height: frameWidth / PhotoCropGeometry.aspectRatio, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(self.gesture(geometry, frameWidth: frameWidth))
        .allowsHitTesting(!self.model.isRendering)
        .overlay {
          if self.model.isRendering {
            ProgressView()
              .controlSize(.large)
          }
        }
    }
    .aspectRatio(PhotoCropGeometry.aspectRatio, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func gesture(_ geometry: PhotoCropGeometry, frameWidth: CGFloat) -> some Gesture {
    DragGesture()
      .simultaneously(with: MagnifyGesture())
      .updating(self.$live) { value, state, _ in
        state = Self.updated(state, with: value)
        self.lastLive.value = state
      }
      .onEnded { value in
        // 화면과 같은 값·같은 계산으로 확정한다.
        let live = Self.updated(self.lastLive.value, with: value)
        self.lastLive.value = CropGesture()
        self.committed = live.committing(geometry, frameWidth: frameWidth, committed: self.committed)
      }
  }

  private static func updated(
    _ gesture: CropGesture,
    with value: SimultaneousGesture<DragGesture, MagnifyGesture>.Value
  ) -> CropGesture {
    gesture.updated(translation: value.first?.translation, magnification: value.second.map { Double($0.magnification) })
  }
}
