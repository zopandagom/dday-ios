import Testing
@testable import ReminderFeature

/// 회차 겹침 판단 (§4.2 전이 표). mutating 호출은 `#expect` 밖에서 하고 반환값을 본다.
struct ReminderSchedulePassTests {
  @Test("처음 요청: 돌기 시작, 요청 바람은 인자대로")
  func firstRequestStartsRunning() {
    var pass = ReminderSchedulePass()
    let started = pass.requested(requestAuthorizationIfNeeded: false)
    #expect(started)
    #expect(pass.isRunning && !pass.needsRerun && !pass.wantsAuthorizationRequest)

    var wanting = ReminderSchedulePass()
    let wantingStarted = wanting.requested(requestAuthorizationIfNeeded: true)
    #expect(wantingStarted)
    #expect(wanting.isRunning && !wanting.needsRerun && wanting.wantsAuthorizationRequest)
  }

  @Test("도는 중 요청: 바로 돌아가고 한 번 더 표시, 요청 바람은 켜기만 한다")
  func requestWhileRunningMarksRerun() {
    var pass = ReminderSchedulePass()
    _ = pass.requested(requestAuthorizationIfNeeded: false)

    let second = pass.requested(requestAuthorizationIfNeeded: false)
    #expect(!second)
    #expect(pass.isRunning && pass.needsRerun && !pass.wantsAuthorizationRequest)

    let wanting = pass.requested(requestAuthorizationIfNeeded: true)
    #expect(!wanting)
    #expect(pass.needsRerun && pass.wantsAuthorizationRequest)

    let plain = pass.requested(requestAuthorizationIfNeeded: false)
    #expect(!plain)
    #expect(pass.wantsAuthorizationRequest)
  }

  @Test("회차 시작: 요청 바람을 넘기고 한 번 더·바람을 끈다. 같은 회차에서 다시 시작하면 false")
  func passStartedHandsOverWish() {
    var pass = ReminderSchedulePass()
    _ = pass.requested(requestAuthorizationIfNeeded: true)
    _ = pass.requested(requestAuthorizationIfNeeded: false)

    let wantsRequest = pass.passStarted()
    #expect(wantsRequest)
    #expect(pass.isRunning && !pass.needsRerun && !pass.wantsAuthorizationRequest)
    let again = pass.passStarted()
    #expect(!again)
  }

  @Test("회차 끝: 한 번 더가 없으면 돌기 끝, 있으면 돌기 유지")
  func passFinished() {
    var single = ReminderSchedulePass()
    _ = single.requested(requestAuthorizationIfNeeded: false)
    _ = single.passStarted()
    let singleAgain = single.passFinished()
    #expect(!singleAgain)
    #expect(single == ReminderSchedulePass())

    var rerun = ReminderSchedulePass()
    _ = rerun.requested(requestAuthorizationIfNeeded: false)
    _ = rerun.passStarted()
    _ = rerun.requested(requestAuthorizationIfNeeded: false)
    let rerunAgain = rerun.passFinished()
    #expect(rerunAgain)
    #expect(rerun.isRunning && rerun.needsRerun)
    _ = rerun.passStarted()
    #expect(!rerun.needsRerun)
  }

  @Test("회차 중 요청이 세 번 와도 한 번만 더 (총 두 회차)")
  func manyRequestsRerunOnce() {
    var pass = ReminderSchedulePass()
    var passes = 0
    let started = pass.requested(requestAuthorizationIfNeeded: false)
    #expect(started)
    repeat {
      _ = pass.passStarted()
      passes += 1
      if passes == 1 {
        for _ in 0 ..< 3 {
          let overlapped = pass.requested(requestAuthorizationIfNeeded: false)
          #expect(!overlapped)
        }
      }
    } while pass.passFinished()
    #expect(passes == 2)
    #expect(!pass.isRunning)
  }

  @Test("회차 중 권한 요청 바람은 다음 회차로 넘어간다")
  func wishMovesToNextPass() {
    var pass = ReminderSchedulePass()
    _ = pass.requested(requestAuthorizationIfNeeded: false)
    let first = pass.passStarted()
    #expect(!first)
    _ = pass.requested(requestAuthorizationIfNeeded: true)
    let rerun = pass.passFinished()
    #expect(rerun)
    let second = pass.passStarted()
    #expect(second)
    let finishedAgain = pass.passFinished()
    #expect(!finishedAgain)
    #expect(!pass.wantsAuthorizationRequest)
  }

  @Test("돌지 않을 때 회차 시작·끝은 false 이고 값을 바꾸지 않는다")
  func callsWhileIdleAreIgnored() {
    var pass = ReminderSchedulePass()
    let started = pass.passStarted()
    let finished = pass.passFinished()
    #expect(!started)
    #expect(!finished)
    #expect(pass == ReminderSchedulePass())
  }
}
