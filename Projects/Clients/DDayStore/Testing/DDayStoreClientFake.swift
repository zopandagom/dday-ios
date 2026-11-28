import Core
import DDayStoreInterface
import Foundation
import Synchronization

/// 메모리에 디데이를 두는 저장소. 규칙(id 중복·없는 id·시각·순서·사진 변경)은 Impl 과 같다. 읽지 못하는 행은 없다.
/// 주입한 `makeID`·`now` 도 Impl 과 같은 때에 부른다: `add` 는 id 를 먼저 만들고, `add`·`update` 는 읽기 실패·
/// `.notFound`·`.alreadyExists` 판정을 통과한 뒤에 시각을 정한다. 사진 id 는 시각 다음에 makeID 로 만든다
/// (`.replace` 일 때만, Impl 과 같은 때). `failNextCall` 로 넣은 에러도 Impl 이 그 에러로 실패하는 지점에서 던진다:
/// `.saveFailed` 는 시각·사진 id 를 정한 뒤(저장 직전)에, 그 밖의 에러는 처음에 던진다. 실패한 호출은 디데이·압축본을
/// 바꾸지 않는다. `now`·`makeID` 는 잠금 안에서 부를 수 있으므로 이 Fake 를 다시 부르면 안 된다.
///
/// 폴더: Fake 의 상태는 "열고 난 뒤의 저장소"라 **기본 폴더를 만들지 않는다**. 기본 폴더가 필요한 테스트·Example 은
/// `folders: DDayStoreClientFake.defaultFolders` 를 넘긴다. 폴더 목록은 폴더 쓰기 4개로 바뀐다 (규칙은 Impl 과 같다,
/// 순서 값 대신 배열 순서). 기본 폴더 키는 init 의 `folders` 중 이름이 `.system(키)` 인 폴더에만 있다고 본다 (Fake 한계:
/// init 에 `.custom` 이름으로 넣은 폴더는 기본 폴더 키가 없어 `.system` 이름으로 되돌릴 수 없다).
/// 폴더 쓰기도 Impl 과 같은 때에 부른다: `addFolder` 는 이름 검증 뒤 id 를 만들고 중복 확인 뒤 시각을 부르며(값은 쓰지
/// 않는다), `updateFolder` 는 `.notFound`·이름 검증 뒤 시각을 부른다. `moveFolders`·`deleteFolder` 는 id·시각을 쓰지 않는다.
/// 없는 폴더를 가리키는 folderID 는 Impl 처럼 미분류(nil)다: `add`·`update` 는 중복·`.notFound` 판정 뒤, 시각 전에
/// 정규화해 저장·반환하고, `fetchAll` 은 init 으로 넣은 디데이가 없는 폴더를 가리키면 nil 로 바꿔 돌려준다
/// (저장 상태 `dDays` 는 그대로).
public final class DDayStoreClientFake: DDayStoreClient {
  // 폴더 편집(DDayStoreClientFake+FolderEditing.swift)이 같은 상태를 쓰도록 private 이 아니다.
  struct State {
    var dDays: [UUID: DDay]
    /// 디데이 id → 압축본 JPEG.
    var images: [UUID: Data]
    var folders: [DDayFolder]
    /// 폴더 id → 기본 폴더 키 (Impl 행의 `systemKey`). 이름을 `.custom` 으로 바꿔도 남긴다.
    var systemKeys: [UUID: DefaultFolder]
    var nextError: DDayStoreError?
  }

  let state: Mutex<State>
  let now: @Sendable () -> Date
  let makeID: @Sendable () -> UUID

  /// 기본 폴더 4개 (`DefaultFolder` 순서, 이름 `.system`, 색·아이콘은 `DefaultFolder` 값).
  /// id 는 테스트에서 비교할 수 있게 고정한다: `00000000-0000-0000-0000-F0000000000n` (n = order + 1).
  public static let defaultFolders: [DDayFolder] = DefaultFolder.allCases.map { folder in
    DDayFolder(
      id: DDayStoreClientFake.defaultFolderID(order: folder.order),
      name: .system(folder),
      color: folder.color,
      icon: folder.icon
    )
  }

  /// `photoImages` 는 디데이 id → 압축본 JPEG (사진이 있는 디데이의 `fetchPhoto` 결과).
  /// `folders` 는 `fetchFolders` 가 돌려줄 폴더 (그 순서 그대로). 기본은 폴더 없음.
  public init(
    dDays: [DDay] = [],
    photoImages: [UUID: Data] = [:],
    folders: [DDayFolder] = [],
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 0) },
    makeID: @escaping @Sendable () -> UUID = UUID.init
  ) {
    self.state = Mutex(State(
      dDays: Dictionary(dDays.map { ($0.id, $0) }) { _, last in last },
      images: photoImages,
      folders: folders,
      systemKeys: Self.systemKeys(of: folders),
      nextError: nil
    ))
    self.now = now
    self.makeID = makeID
  }

  /// 지금 저장된 디데이 (fetchAll 과 같은 순서).
  public var dDays: [DDay] {
    self.state.withLock { Self.sorted($0.dDays) }
  }

  /// 지금 저장된 압축본 (디데이 id → JPEG). 테스트·Example 확인용.
  public var photoImages: [UUID: Data] {
    self.state.withLock { $0.images }
  }

  /// 지금 폴더 (fetchFolders 와 같은 순서). 테스트·Example 확인용.
  public var folders: [DDayFolder] {
    self.state.withLock { $0.folders }
  }

  /// 다음 호출 한 번(어느 메서드든)이 `error` 로 실패한다. 실패한 호출은 상태를 바꾸지 않는다.
  /// 그 호출이 먼저 `.notFound`·`.alreadyExists`·`.invalidFolderName` 로 끝나면 넣은 에러는 쓰이지 않고 사라진다 (Impl 이 저장까지 가지 않는 것과 같다).
  public func failNextCall(with error: DDayStoreError) {
    self.state.withLock { $0.nextError = error }
  }

  public func fetchAll() async throws(DDayStoreError) -> [DDay] {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> [DDay] in
      try Self.takeNextError(&locked)
      let folderIDs = Set(locked.folders.map(\.id))
      return Self.sorted(locked.dDays).map { Self.normalizingFolder($0, folderIDs: folderIDs) }
    }
  }

  public func add(_ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    let id = self.makeID()
    return try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard locked.dDays[id] == nil else { throw DDayStoreError.alreadyExists }
      let folderID = Self.existingFolderID(draft.folderID, in: locked)
      let timestamp = self.now()
      let newPhoto = self.makeNewPhoto(for: draft.photo)
      if let injected {
        throw injected
      }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: timestamp,
        updatedAt: timestamp,
        photo: newPhoto?.photo,
        folderID: folderID
      )
      locked.dDays[id] = dDay
      // 추가에서 `.keep`·`.remove` 는 사진 없음. 새 id 라 남은 압축본은 없지만 맞춰 둔다.
      locked.images[id] = newPhoto?.image
      return dDay
    }
  }

  public func update(id: UUID, _ draft: DDayDraft) async throws(DDayStoreError) -> DDay {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> DDay in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard let existing = locked.dDays[id] else { throw DDayStoreError.notFound }
      let folderID = Self.existingFolderID(draft.folderID, in: locked)
      let timestamp = self.now()
      let newPhoto = self.makeNewPhoto(for: draft.photo)
      if let injected {
        throw injected
      }
      let photo: DDayPhoto?
      switch draft.photo {
      case .keep:
        photo = existing.photo
      case .replace:
        photo = newPhoto?.photo
        locked.images[id] = newPhoto?.image
      case .remove:
        photo = nil
        locked.images[id] = nil
      }
      let dDay = DDay(
        id: id,
        title: draft.title,
        schedule: draft.schedule,
        reminder: draft.reminder,
        createdAt: existing.createdAt,
        updatedAt: timestamp,
        photo: photo,
        folderID: folderID
      )
      locked.dDays[id] = dDay
      return dDay
    }
  }

  public func delete(id: UUID) async throws(DDayStoreError) {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) in
      let injected = try Self.takeErrorBeforeSave(&locked)
      guard locked.dDays[id] != nil else { throw DDayStoreError.notFound }
      if let injected {
        throw injected
      }
      locked.dDays[id] = nil
      locked.images[id] = nil
    }
  }

  public func fetchPhoto(id: UUID) async throws(DDayStoreError) -> Data? {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> Data? in
      try Self.takeNextError(&locked)
      guard let dDay = locked.dDays[id] else { throw DDayStoreError.notFound }
      guard dDay.photo != nil else { return nil }
      return locked.images[id]
    }
  }

  public func fetchFolders() async throws(DDayStoreError) -> [DDayFolder] {
    try self.state.withLock { (locked: inout State) throws(DDayStoreError) -> [DDayFolder] in
      try Self.takeNextError(&locked)
      return locked.folders
    }
  }

  /// 이름이 `.system(키)` 인 폴더의 id → 키.
  private static func systemKeys(of folders: [DDayFolder]) -> [UUID: DefaultFolder] {
    var keys: [UUID: DefaultFolder] = [:]
    for folder in folders {
      if case let .system(key) = folder.name {
        keys[folder.id] = key
      }
    }
    return keys
  }

  /// `.replace` 면 새 사진 id 를 만들어 목록용 사진과 압축본을 돌려준다 (시각 다음에 부른다, Impl 과 같은 때).
  private func makeNewPhoto(for change: DDayPhotoChange) -> (photo: DDayPhoto, image: Data)? {
    guard case let .replace(cardPhoto) = change else { return nil }
    return (DDayPhoto(id: self.makeID(), thumbnail: cardPhoto.thumbnail), cardPhoto.image)
  }

  /// 있는 폴더 id 면 그대로, 없는 폴더면 nil (미분류).
  private static func existingFolderID(_ folderID: UUID?, in state: State) -> UUID? {
    folderID.flatMap { id in state.folders.contains { $0.id == id } ? id : nil }
  }

  /// 디데이의 folderID 가 `folderIDs` 에 없으면 nil 로 바꾼 값 (`fetchAll`).
  private static func normalizingFolder(_ dDay: DDay, folderIDs: Set<UUID>) -> DDay {
    guard let folderID = dDay.folderID, !folderIDs.contains(folderID) else { return dDay }
    return self.withoutFolder(dDay)
  }

  /// folderID 만 nil 로 바꾼 값 (그 밖의 필드는 그대로).
  static func withoutFolder(_ dDay: DDay) -> DDay {
    DDay(
      id: dDay.id,
      title: dDay.title,
      schedule: dDay.schedule,
      reminder: dDay.reminder,
      createdAt: dDay.createdAt,
      updatedAt: dDay.updatedAt,
      photo: dDay.photo
    )
  }

  private static func defaultFolderID(order: Int) -> UUID {
    // 형식이 고정된 리터럴이라 실패하지 않는다. 그래도 강제 언래핑 대신 새 UUID 로 물러난다.
    UUID(uuidString: String(format: "00000000-0000-0000-0000-F%011d", order + 1)) ?? UUID()
  }

  private static func takeNextError(_ state: inout State) throws(DDayStoreError) {
    if let error = state.nextError {
      state.nextError = nil
      throw error
    }
  }

  /// 넣은 에러를 꺼낸다. `.saveFailed` 가 아니면 바로 던지고, `.saveFailed` 면 저장 직전에 던지도록 돌려준다.
  static func takeErrorBeforeSave(_ state: inout State) throws(DDayStoreError) -> DDayStoreError? {
    guard let error = state.nextError else { return nil }
    state.nextError = nil
    guard error == .saveFailed else { throw error }
    return error
  }

  static func sorted(_ dDays: [UUID: DDay]) -> [DDay] {
    dDays.values.sorted { lhs, rhs in
      if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt < rhs.createdAt
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }
}
