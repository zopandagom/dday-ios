import Combine
import Core
import DesignSystem
import SwiftUI

/// 디데이 상세. 상태를 읽어 그리기만 하고, 사용자 동작·앱 상태 변화는 Model 의 이벤트 메서드로 넘긴다.
/// NavigationStack 과 이 화면으로의 `navigationDestination` 은 App·Example 이 붙인다.
public struct DDayDetailView: View {
  let model: DDayDetailModel
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale

  public init(model: DDayDetailModel) {
    self.model = model
  }

  public var body: some View {
    List {
      Section {
        self.header
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
      Section {
        self.rows
      }
    }
    .listStyle(.insetGrouped)
    // 사용자 입력 그대로 (문구 키로 쓰지 않는다)
    .navigationTitle(Text(verbatim: self.model.dDay.title))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      // 지워진 뒤 닫히지 않았을 때를 대비해 숨긴다 (뒤로 가기로는 돌아갈 수 있다).
      ToolbarItem(placement: .primaryAction) {
        if !self.model.isRemoved {
          Button {
            self.model.editButtonTapped()
          } label: {
            Text(HomeText.detailEdit)
          }
        }
      }
    }
    .onAppear {
      self.model.onAppear()
    }
    .onChange(of: self.scenePhase) { _, phase in
      if phase == .active {
        self.model.sceneBecameActive()
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

  /// 사진, 제목, 카운트.
  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      DetailPhotoView(
        photo: self.model.dDay.photo,
        largePhoto: self.model.largePhoto,
        folderColor: self.model.folder?.color
      )
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        // 사용자 입력 그대로 (문구 키로 쓰지 않는다)
        Text(verbatim: self.model.dDay.title)
          .font(.title2.bold())
        Spacer(minLength: 8)
        Text(HomeText.count(self.model.status.label))
          .font(.largeTitle.bold())
          .monospacedDigit()
      }
      .padding(.horizontal, 4)
    }
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var rows: some View {
    let schedule = self.model.dDay.schedule
    LabeledContent {
      if let folder = self.model.folder {
        FolderLabel(name: folder.name, color: folder.color, icon: folder.icon)
      } else {
        FolderLabel.unfiled
      }
    } label: {
      Text(HomeText.detailFolder)
    }
    LabeledContent {
      VStack(alignment: .trailing, spacing: 2) {
        Text(verbatim: HomeText.dateText(self.model.status.date, locale: self.locale))
        if let solar = self.solarDay {
          Text(verbatim: HomeText.detailSolarDate(solar, locale: self.locale))
            .font(.footnote)
        }
      }
    } label: {
      Text(HomeText.detailDate)
    }
    if schedule.repeatRule == .yearly, schedule.countingStyle == .dDay {
      LabeledContent {
        Text(verbatim: HomeText.dateText(schedule.date, locale: self.locale))
      } label: {
        Text(HomeText.detailFirstDate)
      }
    }
    // 반복은 D-day 방식에서만 쓴다.
    if schedule.countingStyle == .dDay {
      LabeledContent {
        Text(HomeText.repeatText(schedule.repeatRule))
      } label: {
        Text(HomeText.detailRepeat)
      }
    }
    LabeledContent {
      Text(HomeText.countingText(schedule.countingStyle))
    } label: {
      Text(HomeText.detailCounting)
    }
  }

  /// 카운트가 가리키는 날짜가 음력이면 그 양력 날짜. 양력이거나 계산할 수 없으면 nil.
  private var solarDay: CalendarDay? {
    guard case let .lunar(lunar) = self.model.status.date else { return nil }
    return KoreanLunarCalendar.solarDay(from: lunar)
  }
}
