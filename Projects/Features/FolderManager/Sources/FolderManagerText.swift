import Core
import Foundation

/// 폴더 관리·폴더 폼 문구. 모두 이 모듈의 `Localizable.xcstrings`(ko·en)에서 온다.
/// 키는 `folderManager.`·`folderForm.` 으로 시작하는 문자열 리터럴로 쓰고, 값은 `\(String(…))` 로만 넣는다 (카탈로그 키의 `%@`).
/// 예외: 아이콘 이름(`iconName(_:)`)은 키를 `folderForm.icon.<rawValue>` 로 만들어서 컴파일러가 확인하지 못하므로
/// `FolderManagerTextTests` 가 모든 `FolderIcon` 의 ko·en 문구를 확인한다.
/// 숫자를 문자열로 넘기는 것은 Int 보간(`%lld`)이 로캘 자릿수 구분을 붙이기 때문이다.
enum FolderManagerText {
  static var title: LocalizedStringResource { self.resource("folderManager.title") }
  static var close: LocalizedStringResource { self.resource("folderManager.close") }
  static var add: LocalizedStringResource { self.resource("folderManager.add") }
  static var empty: LocalizedStringResource { self.resource("folderManager.empty") }
  static var delete: LocalizedStringResource { self.resource("folderManager.delete") }
  static var cancel: LocalizedStringResource { self.resource("folderManager.cancel") }
  static var confirm: LocalizedStringResource { self.resource("folderManager.confirm") }
  static var deleteDialogTitle: LocalizedStringResource { self.resource("folderManager.deleteDialog.title") }
  static var deleteMessageEmpty: LocalizedStringResource { self.resource("folderManager.deleteDialog.messageEmpty") }
  static var deleteMoveToUnfiled: LocalizedStringResource {
    self.resource("folderManager.deleteDialog.moveToUnfiled")
  }

  static var deleteDDays: LocalizedStringResource { self.resource("folderManager.deleteDialog.deleteDDays") }
  static var moveFailedTitle: LocalizedStringResource { self.resource("folderManager.moveFailed.title") }
  static var deleteFailedTitle: LocalizedStringResource { self.resource("folderManager.deleteFailed.title") }
  static var failedMessage: LocalizedStringResource { self.resource("folderManager.failed.message") }

  static var formAddTitle: LocalizedStringResource { self.resource("folderForm.addTitle") }
  static var formEditTitle: LocalizedStringResource { self.resource("folderForm.editTitle") }
  static var formSave: LocalizedStringResource { self.resource("folderForm.save") }
  static var formName: LocalizedStringResource { self.resource("folderForm.name") }
  static var namePlaceholder: LocalizedStringResource { self.resource("folderForm.namePlaceholder") }
  static var formColor: LocalizedStringResource { self.resource("folderForm.color") }
  static var formIcon: LocalizedStringResource { self.resource("folderForm.icon") }
  static var saveFailedTitle: LocalizedStringResource { self.resource("folderForm.saveFailed.title") }
  static var saveFailedMessage: LocalizedStringResource { self.resource("folderForm.saveFailed.message") }
  static var formConfirm: LocalizedStringResource { self.resource("folderForm.confirm") }

  /// 행의 디데이 수 ("3개").
  static func dDayCount(_ count: Int) -> LocalizedStringResource {
    self.resource("folderManager.dDayCount \(String(count))")
  }

  /// 디데이가 있는 폴더의 삭제 확인 메시지.
  static func deleteMessageWithDDays(_ count: Int) -> LocalizedStringResource {
    self.resource("folderManager.deleteDialog.messageWithDDays \(String(count))")
  }

  /// 이름 글자 수 ("5/20").
  static func nameLength(_ length: Int, _ max: Int) -> LocalizedStringResource {
    self.resource("folderForm.nameLength \(String(length)) \(String(max))")
  }

  /// 이름이 너무 길 때 안내.
  static func nameTooLong(_ max: Int) -> LocalizedStringResource {
    self.resource("folderForm.nameTooLong \(String(max))")
  }

  /// 색 이름 (선택 버튼의 접근성 라벨).
  static func colorName(_ color: FolderColor) -> LocalizedStringResource {
    switch color {
    case .blushPink: self.resource("folderForm.color.blushPink")
    case .lavender: self.resource("folderForm.color.lavender")
    case .peach: self.resource("folderForm.color.peach")
    case .mint: self.resource("folderForm.color.mint")
    case .butter: self.resource("folderForm.color.butter")
    }
  }

  /// 아이콘 이름 (선택 버튼의 접근성 라벨). 키는 `folderForm.icon.<rawValue>` 이고 카탈로그에 케이스마다 수동으로 둔다
  /// (케이스가 많아 switch 대신 rawValue 로 키를 만든다. 빠진 키는 `FolderManagerTextTests` 가 잡는다).
  static func iconName(_ icon: FolderIcon) -> LocalizedStringResource {
    self.resource(String.LocalizationValue("folderForm.icon." + icon.rawValue))
  }

  private static func resource(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
  }
}
