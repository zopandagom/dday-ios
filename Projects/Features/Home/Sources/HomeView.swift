import Combine
import Core
import DDayStoreInterface
import DesignSystem
import SwiftUI

/// 홈 목록. 상태를 읽어 그리기만 하고, 사용자 동작·앱 상태 변화는 Model 의 이벤트 메서드로 넘긴다.
/// 목록이 있고 폴더가 하나라도 있으면 위에 칩 줄(전체·폴더들·미분류·폴더 관리)을 둔다 (필터 결과가 비어도 남는다).
/// 폴더 관리는 목록이 있을 때 툴바 왼쪽 폴더 버튼으로도 연다 (폴더가 0개여도).
/// NavigationStack 과 상세(`DDayDetailView`) `navigationDestination` 은 App·Example 이 붙인다.
public struct HomeView: View {
  let model: HomeModel
  @Environment(\.scenePhase) private var scenePhase
  /// iOS 26+ 칩 줄의 첫 칩 왼쪽 여백. 목록 가장자리 여백(기기마다 16·20pt)을 칩 줄 행에서 재어 맞춘다.
  @State private var chipBarInset: CGFloat = 16
  /// 칩 줄 안쪽 여백으로 받을 잰 값의 범위 (목록 가장자리 여백: iPhone 16pt, Pro Max 20pt).
  /// 앱은 세로 화면만 지원하므로(PRODUCT §2 "최소 지원") 가로 안전 영역이 더해지는 경우는 없다.
  private static let chipBarInsetRange: Range<CGFloat> = 0 ..< 40

  public init(model: HomeModel) {
    self.model = model
  }

  public var body: some View {
    self.content
      .navigationTitle(Text(HomeText.title))
      .toolbar {
        // 폴더 관리는 목록이 있을 때만 (칩 줄과 같은 조건의 일부).
        if case .loaded = self.model.content {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              self.model.folderManagerButtonTapped()
            } label: {
              Image(systemName: "folder")
            }
            .accessibilityLabel(Text(HomeText.folderManager))
          }
        }
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

  /// 모든 상태에서 같은 `List` 하나를 둔다. 목록이 아닌 상태(불러오는 중·오류·빈 화면)는 그 안의 안내 행으로 그린다.
  /// 내비게이션 바는 큰 제목을 화면의 스크롤 뷰에 묶는데, 상태마다 다른 뷰(스크롤 뷰가 아닌 빈 화면 등)로 바꾸면
  /// 스크롤 뷰를 잃어 큰 제목이 사라지고 목록으로 돌아와도 돌아오지 않는다.
  ///
  /// 칩 줄 자리는 iOS 버전마다 다르다.
  /// - iOS 26+: 목록 첫 섹션의 행으로 두어 목록과 함께 스크롤한다(`scrollingChipBarSection`). iOS 26+ 의 큰 제목은
  ///   스크롤 위치를 따라 움직여서(아래로 당기면 내려온다) 목록 위에 고정한 칩 줄(`safeAreaInset`)에 가려진다.
  ///   `safeAreaBar` 로 고정하면 큰 제목이 스크롤 가장자리 효과 안에 놓여 멈춰 있을 때도 흐리게 보인다.
  /// - iOS 18~25: 큰 제목이 내비게이션 바 안에 있어 `safeAreaInset` 으로 목록 위에 고정한다.
  private var content: some View {
    let items = self.listItems
    return GeometryReader { proxy in
      List {
        if #available(iOS 26, *), self.isChipBarVisible {
          self.scrollingChipBarSection
        }
        Section {
          if items.isEmpty {
            self.placeholder
              .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.7)
              .listRowBackground(Color.clear)
          } else {
            ForEach(items) { item in
              self.row(item)
            }
          }
        }
      }
      .listSectionSpacing(.compact)
      // 목록이 아닌 상태는 지금처럼 기본 배경 위에 안내를 그린다 (목록 배경을 숨긴다).
      .scrollContentBackground(items.isEmpty ? .hidden : .automatic)
      .safeAreaInset(edge: .top, spacing: 0) {
        if self.isChipBarVisible, !Self.chipBarScrollsWithList {
          self.chipBar(horizontalPadding: 16)
            // 배경은 칩 줄 영역에만 둔다. 기본값(안전 영역까지 늘림)이면 bar 재질이 위의 큰 제목까지 덮어 흐리게 보인다.
            .background(.bar, ignoresSafeAreaEdges: [])
        }
      }
      .animation(.default, value: items.map(\.id))
    }
  }

  /// iOS 26+ 에서 목록과 함께 스크롤하는 칩 줄 섹션. 섹션 머리는 글자 크기·색을 바꿔 칩이 작고 흐리게 보여서
  /// 배경 없는 행으로 둔다.
  /// 목록(insetGrouped) 행은 섹션의 둥근 모양으로 잘려 칩 줄이 가장자리 여백 안에서 둥글게 잘린다(`scrollClipDisabled`
  /// 로도 풀리지 않는다). 그래서 이 섹션만 가장자리 여백을 0 으로 두어 행이 화면 양 끝까지 닿게 하고, 칩 줄을 행 여백만큼
  /// 바깥으로 넓혀 화면 끝까지 스크롤하게 한다. 가만히 있을 때 첫 칩은 행 여백 자리(큰 제목·카드 섹션과 같은 왼쪽 선)에서
  /// 시작한다. 행 여백은 목록 가장자리 여백과 같아서 그 자리를 재어 칩 줄 안쪽 여백으로 쓴다.
  @available(iOS 26, *)
  private var scrollingChipBarSection: some View {
    Section {
      self.chipBar(horizontalPadding: self.chipBarInset)
        // 행 너비는 그대로 두고 칩 줄만 행 여백만큼 양옆으로 넓힌다 (아래에서 재는 자리는 바뀌지 않는다).
        .padding(.horizontal, -self.chipBarInset)
        .onGeometryChange(for: CGFloat.self) { proxy in
          proxy.frame(in: .scrollView).minX
        } action: { inset in
          // 상세 push·pop 전환 중에는 홈이 옆으로 밀려 엉뚱한 값이 잡힐 수 있다. 행 여백으로 있을 수 있는 범위만 받는다.
          guard Self.chipBarInsetRange.contains(inset) else { return }
          self.chipBarInset = inset
        }
        .listRowInsets(.vertical, 0)
        .listRowBackground(Color.clear)
    }
    .listSectionMargins(.horizontal, 0)
    // 가장자리 여백이 0 인 섹션은 위아래에 구분선이 생긴다.
    .listSectionSeparator(.hidden)
  }

  /// 칩 줄을 목록과 함께 스크롤할지 (iOS 26+). 아니면 목록 위에 고정한다. `content` 설명 참고.
  private static var chipBarScrollsWithList: Bool {
    if #available(iOS 26, *) {
      true
    } else {
      false
    }
  }

  /// 목록으로 그릴 항목. 목록이 아닌 상태는 비어 있다.
  private var listItems: [HomeItem] {
    if case let .loaded(items) = self.model.content {
      return items
    }
    return []
  }

  /// 목록이 아닌 상태의 안내. 목록이 있으면 아무것도 그리지 않는다.
  @ViewBuilder
  private var placeholder: some View {
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
    case .loaded:
      EmptyView()
    }
  }

  /// 칩 줄은 목록이 있고 폴더가 하나라도 있을 때 둔다 (필터 결과가 비어도 남는다).
  private var isChipBarVisible: Bool {
    if case .loaded = self.model.content {
      return !self.model.folders.isEmpty
    }
    return false
  }

  /// 칩 줄: 전체 → 폴더들(순서대로) → 미분류 → [폴더 관리].
  private func chipBar(horizontalPadding: CGFloat) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        self.chip(Text(HomeText.filterAll), color: nil, icon: nil, filter: .all)
        ForEach(self.model.folders) { folder in
          self.chip(folder.name.text, color: folder.color, icon: folder.icon, filter: .folder(folder.id))
        }
        self.chip(Text(FolderText.unfiled), color: nil, icon: nil, filter: .unfiled)
        FolderChip(title: Text(HomeText.folderManager), color: nil, icon: nil, isSelected: false) {
          self.model.folderManagerButtonTapped()
        }
      }
      .padding(.horizontal, horizontalPadding)
      .padding(.vertical, 8)
    }
    .scrollIndicators(.hidden)
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

  private func row(_ item: HomeItem) -> some View {
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
