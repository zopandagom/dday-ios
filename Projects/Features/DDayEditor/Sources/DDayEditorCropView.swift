import Core
import PhotoInterface
import SwiftUI

/// 3:2 자르기 화면 (편집 시트 안 내비게이션 push). 끌어서 옮기고 두 손가락으로 확대한다.
/// 제스처 중 영역은 `PhotoCropGeometry.crop(zoom:center:)` 로 계속 클램프하고, 끝나면 확대·중심을 View 일시 상태에 둔다.
/// 끌기와 확대는 한 제스처(`simultaneously`)의 한 값(`LiveGesture`)으로 그리고 확정한다. 두 손가락을 함께 떼도
/// `onEnded` 순서에 기대지 않고, 손을 떼기 직전에 보인 영역 그대로 확정된다.
/// [완료] 는 그 영역을 Model 의 `cropConfirmed(_:)` 로 넘긴다. 만드는 중에는 버튼·제스처가 막힌다.
struct DDayEditorCropView: View {
  let model: DDayEditorModel
  @State private var zoom: Double = 1
  @State private var center = CGPoint(x: 0.5, y: 0.5)
  @GestureState private var live = LiveGesture()

  /// 진행 중인 끌기 거리(포인트)와 확대 배율. 제스처가 끝나면 초기값으로 돌아간다.
  private struct LiveGesture: Equatable {
    var translation: CGSize = .zero
    var magnification: Double = 1
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
          self.model.cropConfirmed(geometry.crop(zoom: self.zoom, center: self.center))
        } label: {
          Text(DDayEditorText.cropDone)
        }
        // 끌기·확대 중에는 막는다: [완료] 는 확정된 zoom·center 로 만들므로, 진행 중이면 보이는 영역과 달라진다.
        .disabled(self.live != LiveGesture())
      }
    }
  }

  // MARK: - 자르기 틀

  private func cropFrame(image: PhotoWorkingImage, geometry: PhotoCropGeometry) -> some View {
    GeometryReader { proxy in
      let frameWidth = proxy.size.width
      let crop = self.liveCrop(geometry, frameWidth: frameWidth)
      let size = Self.displaySize(geometry, crop: crop, frameWidth: frameWidth)
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
        state = Self.liveGesture(value)
      }
      .onEnded { value in
        // 화면(`liveCrop`)과 같은 값·같은 계산으로 확정한다.
        let live = Self.liveGesture(value)
        let crop = self.crop(geometry, frameWidth: frameWidth, live: live)
        self.zoom = min(max(self.zoom * live.magnification, 1), PhotoCropGeometry.maxZoom)
        self.center = CGPoint(x: crop.midX, y: crop.midY)
      }
  }

  private static func liveGesture(_ value: SimultaneousGesture<DragGesture, MagnifyGesture>.Value) -> LiveGesture {
    LiveGesture(
      translation: value.first?.translation ?? .zero,
      magnification: Double(value.second?.magnification ?? 1)
    )
  }

  /// 제스처 중의 영역 (확정 값 + 진행 중인 이동·확대).
  private func liveCrop(_ geometry: PhotoCropGeometry, frameWidth: CGFloat) -> CGRect {
    self.crop(geometry, frameWidth: frameWidth, live: self.live)
  }

  /// 끈 거리(포인트)를 표시 크기로 정규화해 중심에서 빼고 클램프한다 (오른쪽으로 끌면 왼쪽이 보인다).
  private func crop(_ geometry: PhotoCropGeometry, frameWidth: CGFloat, live: LiveGesture) -> CGRect {
    let zoom = self.zoom * live.magnification
    let translation = live.translation
    let base = geometry.crop(zoom: zoom, center: self.center)
    let size = Self.displaySize(geometry, crop: base, frameWidth: frameWidth)
    guard size.width > 0, size.height > 0 else { return base }
    let center = CGPoint(
      x: self.center.x - translation.width / size.width,
      y: self.center.y - translation.height / size.height
    )
    return geometry.crop(zoom: zoom, center: center)
  }

  /// 영역이 틀을 채우도록 그린 작업 이미지 전체의 크기 (포인트).
  private static func displaySize(_ geometry: PhotoCropGeometry, crop: CGRect, frameWidth: CGFloat) -> CGSize {
    guard crop.width > 0 else { return .zero }
    let width = frameWidth / crop.width
    return CGSize(width: width, height: width * CGFloat(geometry.imageHeight) / CGFloat(geometry.imageWidth))
  }
}
