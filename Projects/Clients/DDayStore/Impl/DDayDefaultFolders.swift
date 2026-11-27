import Core
import Foundation
import os
import SwiftData

/// 기본 폴더 만들기 (컨테이너 준비 단계, `DDayContainerCache` 의 `prepare`).
///
/// - 메타 행(`DDayStoreMetaRecord`, `mainKey`)의 `defaultFoldersCreatedAt` 이 있으면 아무것도 쓰지 않는다. 폴더가
///   몇 개든(0개여도) 다시 만들지 않는다: 사용자가 다 지운 뒤에도 다시 생기지 않는다.
/// - 없으면 `DefaultFolder` 순서로 폴더 4행을 넣고 표시를 채워 save 한 번으로 함께 쓴다. 실패하면 `rollback()` 후
///   던진다: 폴더 4행과 표시는 함께 남거나 함께 없다 (부분 저장 없음). 다음 호출이 다시 열고 다시 시도한다.
/// - 폴더 행이 있는데 표시가 없는 상태는 이 save 가 함께 쓰므로 생기지 않는다. 생기더라도(쓰기 경로 밖) 그대로
///   4개를 더 만든다 (위협 모델 밖).
/// - id·시각은 주입한 `makeID`·`now` 가 아니라 `UUID()`·`Date()` 를 쓴다: Impl 과 Fake 가 `makeID`·`now` 를 부르는
///   때가 같다는 규칙을 지키기 위해서다 (Fake 는 기본 폴더를 만들지 않는다). 테스트는 기본 폴더를 `systemKey` 로 본다.
/// - save 실패 롤백은 단위 테스트로 재현하지 않는다: 메모리·임시 디스크 컨테이너에서 이 save 만 실패시킬 주입 지점이
///   없다 (save 를 감싸는 주입은 이 한 경로를 위해 Impl 구조를 바꾸게 된다). 롤백은 다른 쓰기와 같은 방식이다.
enum DDayDefaultFolders {
  /// 준비 실패를 열기 실패와 구분해 로그에 남기는 에러. 원인 에러 타입 이름은 던지기 전에 따로 로그로 남긴다.
  struct DefaultFolderCreationError: Error {}

  private static let logger = Logger(subsystem: "com.zopandagom.dday", category: "DDayStore")

  /// 기본 폴더가 아직 만들어진 적 없으면 만든다. 실패하면 `DefaultFolderCreationError`.
  static func createIfNeeded(in container: ModelContainer) throws {
    let context = ModelContext(container)
    context.autosaveEnabled = false
    do {
      let mainKey = DDayStoreMetaRecord.mainKey
      var descriptor = FetchDescriptor<DDayStoreMetaRecord>(predicate: #Predicate { $0.key == mainKey })
      descriptor.fetchLimit = 1
      let meta = try context.fetch(descriptor).first
      if meta?.defaultFoldersCreatedAt != nil {
        return
      }
      let now = Date()
      for folder in DefaultFolder.allCases {
        context.insert(DDayFolderRecord(DDayFolderMapping.fields(for: folder, id: UUID(), createdAt: now)))
      }
      if let meta {
        meta.defaultFoldersCreatedAt = now
      } else {
        let newMeta = DDayStoreMetaRecord(key: mainKey)
        newMeta.defaultFoldersCreatedAt = now
        context.insert(newMeta)
      }
      try context.save()
    } catch {
      context.rollback()
      self.logger.error(
        "DDayStore createDefaultFolders failed: \(String(describing: type(of: error)), privacy: .public)"
      )
      throw DefaultFolderCreationError()
    }
  }
}
