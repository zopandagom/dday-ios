import Foundation
import LocalNotificationInterface
import os
import UIKit
import UserNotifications

/// `UNUserNotificationCenter` 로 로컬 알림을 다룬다. 상태가 없고 메서드마다 `UNUserNotificationCenter.current()` 를 쓴다.
///
/// - `requestAuthorization`: 알림·소리만 요청한다 (배지·임시 허용 없음). 에러는 로그만 남기고 다시 읽은 상태를 돌려준다.
/// - `replacePending`: 대기 요청을 모두 지운 뒤(동기 호출, 뒤의 add 보다 먼저 처리된다) 앞 64개를 순서대로 추가한다.
///   64개를 넘게 넣으면 iOS 가 먼저 넣은 것부터 조용히 지우므로 여기서 자른다. 실패는 세고 끝까지 추가한다.
/// - `openSettings`: UIKit 으로 이 앱의 알림 설정 화면(`openNotificationSettingsURLString`)을 연다 (앱 열기 부수효과).
/// 로그에는 개수·에러 코드·열기 결과만 남긴다 (제목·본문·날짜·식별자는 남기지 않는다, PRODUCT §1).
public final class LocalNotificationClientImpl: LocalNotificationClient {
  private static let logger = Logger(subsystem: "com.zopandagom.dday", category: "LocalNotification")

  public init() {}

  public func authorizationStatus() async -> NotificationAuthorization {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return NotificationRequestMapping.authorization(from: settings.authorizationStatus)
  }

  public func requestAuthorization() async -> NotificationAuthorization {
    do {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    } catch {
      let code = (error as NSError).code
      Self.logger.error("requestAuthorization failed: code \(code, privacy: .public)")
    }
    return await self.authorizationStatus()
  }

  public func replacePending(_ requests: [NotificationRequest]) async throws(LocalNotificationError) {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    var added = 0
    var failed = 0
    var firstErrorCode: Int?
    for request in requests.prefix(LocalNotificationLimits.maximumPendingCount) {
      do {
        try await center.add(NotificationRequestMapping.request(for: request))
        added += 1
      } catch {
        failed += 1
        if firstErrorCode == nil {
          firstErrorCode = (error as NSError).code
        }
      }
    }
    guard failed == 0 else {
      let code = firstErrorCode ?? 0
      let total = added + failed
      Self.logger.error(
        "replacePending failed \(failed, privacy: .public)/\(total, privacy: .public), code \(code, privacy: .public)"
      )
      throw .scheduleFailed
    }
    Self.logger.info("replacePending added \(added, privacy: .public)")
  }

  public func openSettings() async -> Bool {
    let opened = await Self.openNotificationSettings()
    Self.logger.info("openSettings opened \(opened, privacy: .public)")
    return opened
  }

  /// `UIApplication.openNotificationSettingsURLString`·`UIApplication.shared` 가 메인 액터 격리라 한 함수에 모은다.
  @MainActor
  private static func openNotificationSettings() async -> Bool {
    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return false }
    return await UIApplication.shared.open(url)
  }
}
