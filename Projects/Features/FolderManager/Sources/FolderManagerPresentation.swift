import Foundation

/// 폴더 관리 시트와 그 안의 폼 push 를 열고 닫는 판단 (순수 값, Model 아님). 모델을 만들고 들고 있는 쪽(App·Example)이
/// 이 값을 함께 들고 돌려준 값대로 한다. 결과 전달(늦은 결과도 늘 관리 모델·홈에)은 판단하지 않는다.
/// - 시트는 떠 있거나, 편집 시트가 떠 있거나, 이전 관리·폼 작업이 아직 저장소에서 끝나지 않았으면 열지 않는다.
/// - 폼은 그 관리 세션이 떠 있고 폼이 없을 때만 연다. 늦게 끝난 옛 폼은 결과만 넘기고 새 폼을 닫지 않는다.
///
/// 상태 전이: 시트 `nil ──open──▶ S ──dismissed──▶ nil`, 폼(S 안에서) `nil ──openForm──▶ F ──formFinished(F) | formDismissed |
/// dismissed──▶ nil`.
public struct FolderManagerPresentation: Equatable, Sendable {
  /// 떠 있는 관리 시트의 세션 id. nil 이면 시트 없음.
  public private(set) var sessionID: UUID?
  /// 떠 있는 폼(시트 안 push)의 세션 id. nil 이면 폼 없음.
  public private(set) var formSessionID: UUID?

  public var isPresented: Bool {
    self.sessionID != nil
  }

  public init() {}

  /// 시트가 없고, 편집 시트가 없고, 이전 관리·폼 작업이 끝났을 때만 `newID` 를 떠 있는 세션으로 두고 돌려준다. 아니면 nil.
  public mutating func open(newID: UUID, isEditorPresented: Bool, isPreviousWorkInFlight: Bool) -> UUID? {
    guard self.sessionID == nil, !isEditorPresented, !isPreviousWorkInFlight else { return nil }
    self.sessionID = newID
    self.formSessionID = nil
    return newID
  }

  /// 그 관리 세션이 떠 있고 폼이 없을 때만 `newID` 를 폼 세션으로 두고 돌려준다. 아니면 nil (두 번 탭·닫힌 세션의 요청).
  public mutating func openForm(newID: UUID, managerSessionID: UUID) -> UUID? {
    guard self.sessionID == managerSessionID, self.formSessionID == nil else { return nil }
    self.formSessionID = newID
    return newID
  }

  /// 그 폼의 저장이 끝남. 떠 있는 폼이면 닫고 true (pop), 아니면 false (이미 닫힌 폼: 결과만 넘긴다).
  public mutating func formFinished(formSessionID: UUID) -> Bool {
    guard self.formSessionID == formSessionID else { return false }
    self.formSessionID = nil
    return true
  }

  /// 폼 바인딩 set(nil) (뒤로 가기). 떠 있으면 닫고 그 id, 없으면 nil (멱등).
  public mutating func formDismissed() -> UUID? {
    guard let formSessionID = self.formSessionID else { return nil }
    self.formSessionID = nil
    return formSessionID
  }

  /// 시트 바인딩 set(nil). 떠 있으면 시트·폼을 닫고 시트 id, 없으면 nil (멱등).
  public mutating func dismissed() -> UUID? {
    guard let sessionID = self.sessionID else { return nil }
    self.sessionID = nil
    self.formSessionID = nil
    return sessionID
  }
}
