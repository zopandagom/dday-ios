import Core
import CoreGraphics
import Foundation
import PhotoInterface
import Synchronization

/// 호출 중간에 멈추는 사진 클라이언트. `loadWorkingImage`·`renderCardPhoto` 는 호출을 기록하고, 테스트가
/// `resume…` 할 때까지 멈춘다 (`ControlledEditorStore` 와 같은 방식). 멈춘 불러오기가 취소되면
/// `cancelledLoadCount` 를 늘리지만 continuation 은 테스트가 resume 할 때까지 그대로 기다린다.
/// 각 테스트는 시작한 호출을 모두 resume 한다. continuation 은 잠금 안에서 꺼내기만 하고 resume 은 잠금 밖에서 한다.
final class ControlledPhotoClient: PhotoClient {
  private struct State {
    var loadCallCount = 0
    var renderedCrops: [CGRect] = []
    var cancelledLoadCount = 0
    var pendingLoads: [CheckedContinuation<Result<PhotoWorkingImage, PhotoError>, Never>] = []
    var pendingRenders: [CheckedContinuation<Result<CardPhoto, PhotoError>, Never>] = []
  }

  private let state = Mutex(State())

  var loadCallCount: Int {
    self.state.withLock { $0.loadCallCount }
  }

  var renderedCrops: [CGRect] {
    self.state.withLock { $0.renderedCrops }
  }

  var cancelledLoadCount: Int {
    self.state.withLock { $0.cancelledLoadCount }
  }

  // MARK: - PhotoClient

  func loadWorkingImage(from _: PickedPhoto) async throws(PhotoError) -> PhotoWorkingImage {
    let result = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        self.state.withLock { state in
          state.loadCallCount += 1
          state.pendingLoads.append(continuation)
        }
      }
    } onCancel: {
      self.state.withLock { $0.cancelledLoadCount += 1 }
    }
    switch result {
    case let .success(image): return image
    case let .failure(error): throw error
    }
  }

  func renderCardPhoto(from _: PhotoWorkingImage, crop: CGRect) async throws(PhotoError) -> CardPhoto {
    let result = await withCheckedContinuation { continuation in
      self.state.withLock { state in
        state.renderedCrops.append(crop)
        state.pendingRenders.append(continuation)
      }
    }
    switch result {
    case let .success(photo): return photo
    case let .failure(error): throw error
    }
  }

  // MARK: - 테스트 조작

  /// 가장 먼저 멈춘 불러오기를 `result` 로 끝낸다.
  func resumeLoad(with result: Result<PhotoWorkingImage, PhotoError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingLoads.isEmpty ? nil : state.pendingLoads.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 가장 먼저 멈춘 만들기를 `result` 로 끝낸다.
  func resumeRender(with result: Result<CardPhoto, PhotoError>) throws {
    let continuation = self.state.withLock { state in
      state.pendingRenders.isEmpty ? nil : state.pendingRenders.removeFirst()
    }
    guard let continuation else { throw ControlledStoreError.nothingPending }
    continuation.resume(returning: result)
  }

  /// 멈춘 불러오기가 `count` 개 이상이 될 때까지 기다린다.
  func waitForPendingLoad(_ count: Int = 1) async throws {
    try await self.waitUntil("load \(count)개") { $0.pendingLoads.count >= count }
  }

  func waitForPendingRender() async throws {
    try await self.waitUntil("render") { !$0.pendingRenders.isEmpty }
  }

  /// 최대 1000 회 확인한다: 처음 100 회는 `Task.yield()`, 그 뒤는 1ms 씩 (합계 약 1초). 넘으면 `timedOut`.
  private func waitUntil(_ label: String, _ condition: (State) -> Bool) async throws {
    for attempt in 0 ..< 1000 {
      if self.state.withLock({ condition($0) }) {
        return
      }
      if attempt < 100 {
        await Task.yield()
      } else {
        try await Task.sleep(for: .milliseconds(1))
      }
    }
    throw ControlledStoreError.timedOut(label)
  }
}
