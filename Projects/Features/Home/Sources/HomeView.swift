import Combine
import SwiftUI

/// 홈 목록. 상태를 읽어 그리기만 하고, 사용자 동작·앱 상태 변화는 Model 의 이벤트 메서드로 넘긴다.
/// NavigationStack 과 상세(`DDayDetailView`) `navigationDestination` 은 App·Example 이 붙인다.
public struct HomeView: View {
  let model: HomeModel
  @Environment(\.scenePhase) private var scenePhase

  public init(model: HomeModel) {
    self.model = model
  }

  public var body: some View {
    self.content
      .navigationTitle(Text(HomeText.title))
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            self.model.addButtonTapped()
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel(Text(HomeText.add))
        }
      }
      .alert(
        Text(HomeText.deleteFailedTitle),
        isPresented: Binding(
          get: { self.model.isDeleteFailedAlertPresented },
          set: { isPresented in
            if !isPresented {
              self.model.deleteFailedAlertDismissed()
            }
          }
        )
      ) {
        Button(HomeText.confirm) {}
      } message: {
        Text(HomeText.deleteFailedMessage)
      }
      .task {
        await self.model.onAppear()
      }
      .onChange(of: self.scenePhase) { _, phase in
        if phase == .active {
          Task { await self.model.sceneBecameActive() }
        }
      }
      // 알림이 메인이 아닌 스레드에서 올 수 있어 메인으로 옮긴다.
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
        .receive(on: DispatchQueue.main))
      { _ in
        self.model.calendarDayChanged()
      }
      .onReceive(
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: DispatchQueue.main)
      ) { _ in
        self.model.calendarDayChanged()
      }
  }

  @ViewBuilder
  private var content: some View {
    switch self.model.content {
    case .loading:
      ProgressView {
        Text(HomeText.loading)
      }
    case .loadFailed:
      ContentUnavailableView {
        Label {
          Text(HomeText.loadFailedTitle)
        } icon: {
          Image(systemName: "exclamationmark.triangle")
        }
      } description: {
        Text(HomeText.loadFailedMessage)
      } actions: {
        Button(HomeText.retry) {
          Task { await self.model.retryButtonTapped() }
        }
        .buttonStyle(.borderedProminent)
      }
    case let .loaded(items) where items.isEmpty:
      ContentUnavailableView {
        Label {
          Text(HomeText.emptyTitle)
        } icon: {
          Image(systemName: "calendar.badge.plus")
        }
      } description: {
        Text(HomeText.emptyMessage)
      } actions: {
        Button(HomeText.add) {
          self.model.addButtonTapped()
        }
        .buttonStyle(.borderedProminent)
      }
    case let .loaded(items):
      self.list(items)
    }
  }

  private func list(_ items: [HomeItem]) -> some View {
    List {
      ForEach(items) { item in
        Button {
          self.model.dDayTapped(id: item.id)
        } label: {
          DDayCardView(item: item)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          // 같은 차례에 숨기도록 Task 로 감싸지 않고 바로 부른다.
          Button(role: .destructive) {
            self.model.deleteSwiped(id: item.id)
          } label: {
            Label {
              Text(HomeText.delete)
            } icon: {
              Image(systemName: "trash")
            }
          }
        }
      }
    }
    .animation(.default, value: items.map(\.id))
  }
}
