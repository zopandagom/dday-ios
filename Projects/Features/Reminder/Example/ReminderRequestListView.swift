import LocalNotificationInterface
import SwiftUI

/// `ReminderModel.scheduledRequests` 목록 (울릴 날짜·시각, 제목, 본문). 제목·본문은 알림에 보일 그대로다.
struct ReminderRequestListView: View {
  let requests: [NotificationRequest]

  var body: some View {
    if self.requests.isEmpty {
      Text("예약된 알림 없음")
        .foregroundStyle(.secondary)
    } else {
      ForEach(self.requests) { request in
        VStack(alignment: .leading, spacing: 4) {
          Text("\(request.day.description) \(request.time.description)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          Text(request.title.isEmpty ? "(제목 없음)" : request.title)
            .font(.headline)
          Text(request.body)
            .font(.subheadline)
        }
        .padding(.vertical, 2)
      }
    }
  }
}
