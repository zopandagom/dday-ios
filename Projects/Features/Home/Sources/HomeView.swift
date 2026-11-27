import Combine
import Core
import DDayStoreInterface
import DesignSystem
import SwiftUI

/// 홈 목록. 상태를 읽어 그리기만 하고, 사용자 동작·앱 상태 변화는 Model 의 이벤트 메서드로 넘긴다.
/// 목록이 있고 폴더가 하나라도 있으면 위에 칩 줄(전체·폴더들·미분류)을 둔다 (필터 결과가 비어도 남는다).
/// NavigationStack 과 상세(`DDayDetailView`) `navigationDestination` 은 App·Example 이 붙인다.
public struct HomeView: View {
  let model: HomeModel
  @Environment(\.scenePhase) private var scenePhase

  public init(model: HomeModel) {
    self.model = model
  }

  public var body: some View {
    self.content
      .safeAreaInset(edge: .top, spacing: 0) {
        if case .loaded = self.model.content, !self.model.folders.isEmpty {
          self.chipBar
        }
      }
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
    case let .loaded(items) where items.isEmpty && self.model.hasDDays:
      // 디데이는 있는데 지금 필터에 맞는 것이 없다. 툴바 [+] 가 있어 버튼은 두지 않는다.
      // 미분류는 폴더가 아니므로 제목·설명을 따로 둔다.
      ContentUnavailableView {
        Label {
          if self.model.filter == .unfiled {
            Text(HomeText.filterEmptyUnfiledTitle)
          } else {
            Text(HomeText.filterEmptyFolderTitle)
          }
        } icon: {
          Image(systemName: "tray")
        }
      } description: {
        if self.model.filter == .unfiled {
          Text(HomeText.filterEmptyUnfiledMessage)
        } else {
          Text(HomeText.filterEmptyFolderMessage)
        }
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

  /// 칩 줄: 전체 → 폴더들(순서대로) → 미분류.
  private var chipBar: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        self.chip(Text(HomeText.filterAll), color: nil, icon: nil, filter: .all)
        ForEach(self.model.folders) { folder in
          self.chip(folder.name.text, color: folder.color, icon: folder.icon, filter: .folder(folder.id))
        }
        self.chip(Text(FolderText.unfiled), color: nil, icon: nil, filter: .unfiled)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .scrollIndicators(.hidden)
    // 배경은 칩 줄 영역에만 둔다. 기본값(안전 영역까지 늘림)이면 bar 재질이 위의 큰 제목까지 덮어 흐리게 보인다.
    .background(.bar, ignoresSafeAreaEdges: [])
  }

  private func chip(_ title: Text, color: FolderColor?, icon: FolderIcon?, filter: HomeFilter) -> some View {
    FolderChip(
      title: title,
      color: color,
      icon: icon,
      isSelected: self.model.filter == filter
    ) {
      self.model.filterSelected(filter)
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
