/// 다시 예약 회차를 하나씩만 돌리고, 도는 중에 온 요청은 끝난 뒤 한 번 더로 모으는 판단 (순수 값, Model 아님).
/// 권한 요청 바람(`wantsAuthorizationRequest`)도 모아 다음에 시작하는 회차 하나에 넘긴다.
/// `ReminderModel` 이 값으로 들고 돌려준 값대로 await 만 한다.
///
/// 불변식: `isRunning == false` 이면 `needsRerun == false` (`passFinished` 가 `needsRerun` 이 꺼졌을 때만 돌기를 끝낸다).
/// 돌기가 끝난 뒤 `wantsAuthorizationRequest` 가 남는 경우는 없다: 그것을 켜는 `requested` 는 늘 돌기를 시작하거나
/// `needsRerun` 을 켜므로 다음 `passStarted` 가 반드시 온다.
struct ReminderSchedulePass: Equatable, Sendable {
  /// 회차가 도는 중 (요청을 받은 뒤 마지막 회차가 끝날 때까지).
  private(set) var isRunning = false
  /// 도는 중에 요청이 와서 지금 회차 뒤에 한 번 더 돌아야 한다.
  private(set) var needsRerun = false
  /// 아직 회차에 넘기지 않은 권한 요청 바람.
  private(set) var wantsAuthorizationRequest = false

  /// 다시 예약 요청이 옴. `requestAuthorizationIfNeeded` 면 바람을 켠다(이미 켜져 있으면 그대로, 끄지 않는다).
  /// 돌고 있지 않으면 돌기 시작으로 바꾸고 true (부른 쪽이 루프를 돈다), 돌고 있으면 `needsRerun` 을 켜고 false (바로 돌아간다).
  mutating func requested(requestAuthorizationIfNeeded: Bool) -> Bool {
    if requestAuthorizationIfNeeded {
      self.wantsAuthorizationRequest = true
    }
    guard !self.isRunning else {
      self.needsRerun = true
      return false
    }
    self.isRunning = true
    return true
  }

  /// 회차 하나를 시작함. `needsRerun` 을 끄고, 권한 요청 바람을 이 회차로 넘겨(끄고) 그 값을 돌려준다.
  /// 돌고 있지 않을 때 부르면(잘못된 호출) false 를 돌려주고 아무것도 바꾸지 않는다.
  mutating func passStarted() -> Bool {
    guard self.isRunning else { return false }
    self.needsRerun = false
    let wantsRequest = self.wantsAuthorizationRequest
    self.wantsAuthorizationRequest = false
    return wantsRequest
  }

  /// 회차 하나가 끝남. `needsRerun` 이면 true (돌기 유지, 한 번 더), 아니면 돌기를 끝내고 false.
  /// 돌고 있지 않을 때 부르면 false.
  mutating func passFinished() -> Bool {
    guard self.isRunning else { return false }
    guard self.needsRerun else {
      self.isRunning = false
      return false
    }
    return true
  }
}
