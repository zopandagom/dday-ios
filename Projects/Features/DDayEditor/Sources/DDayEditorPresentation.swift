import Foundation

/// 편집 시트를 띄우고 닫는 판단 (순수 값, Model 아님).
/// 편집 모델을 만들고 들고 있는 쪽(App·Example)이 이 값을 함께 들고 돌려준 값대로 한다.
/// - 떠 있는 동안 다시 열지 않는다.
/// - 끌어내려 닫은 뒤 늦게 끝난 옛 편집은 결과만 넘기고, 그 사이 새로 연 시트를 닫지 않는다.
///
/// 상태 전이: `nil ──open──▶ A ──finished(A) | dismissed──▶ nil`.
public struct DDayEditorPresentation: Equatable, Sendable {
  /// 떠 있는 시트의 세션 id. nil 이면 시트 없음.
  public private(set) var sessionID: UUID?

  public init() {}

  /// 열기 요청. 떠 있으면 nil (열지 않는다). 아니면 `newID` 를 떠 있는 세션으로 두고 돌려준다 (호출부가 이 id 로 모델을 만든다).
  public mutating func open(newID: UUID) -> UUID? {
    guard self.sessionID == nil else { return nil }
    self.sessionID = newID
    return newID
  }

  /// 그 세션의 편집이 끝남. 떠 있는 세션이면 닫고 true (시트를 내린다), 아니면 false (옛 세션: 결과만 넘긴다).
  public mutating func finished(sessionID: UUID) -> Bool {
    guard self.sessionID == sessionID else { return false }
    self.sessionID = nil
    return true
  }

  /// 시트 바인딩 set(nil). 떠 있으면 닫고 그 id 를 돌려준다 (호출부가 그 모델에 `sheetDismissed()`), 없으면 nil (멱등).
  public mutating func dismissed() -> UUID? {
    guard let sessionID = self.sessionID else { return nil }
    self.sessionID = nil
    return sessionID
  }
}
