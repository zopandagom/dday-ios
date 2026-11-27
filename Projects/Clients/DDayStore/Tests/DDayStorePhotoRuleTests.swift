import Core
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import Testing
@testable import DDayStoreImpl

/// 사진 변경(`.keep`·`.replace`·`.remove`)과 압축본 읽기 규칙을 Impl(메모리 컨테이너)과 Fake 에 같이 돌린다.
struct DDayStorePhotoRuleTests {
  /// 반환값 = `fetchAll` 검사용 경우: 사진 변경 3종 × 추가/수정 (수정은 사진 있는 행에서 시작).
  enum ReturnCase: String, CaseIterable, Sendable {
    case addKeep
    case addReplace
    case addRemove
    case updateKeep
    case updateReplace
    case updateRemove

    var change: DDayPhotoChange {
      switch self {
      case .addKeep, .updateKeep: .keep
      case .addReplace, .updateReplace: .replace(Sample.cardPhoto(seed: 9))
      case .addRemove, .updateRemove: .remove
      }
    }

    var isUpdate: Bool {
      switch self {
      case .addKeep, .addReplace, .addRemove: false
      case .updateKeep, .updateReplace, .updateRemove: true
      }
    }
  }

  @Test("add·update 가 돌려준 디데이(사진 포함)는 fetchAll 의 그 항목과 같다", arguments: StoreKind.allCases, ReturnCase.allCases)
  func returnedValueMatchesFetchAll(kind: StoreKind, returnCase: ReturnCase) async throws {
    let store = try kind.make()
    let returned: DDay
    if returnCase.isUpdate {
      let original = try await store.add(Sample.draft("처음", photo: .replace(Sample.cardPhoto(seed: 1))))
      returned = try await store.update(id: original.id, Sample.draft("바뀜", photo: returnCase.change))
    } else {
      returned = try await store.add(Sample.draft("추가", photo: returnCase.change))
    }

    let fetched = try await store.fetchAll()
    #expect(fetched == [returned])
    switch returnCase {
    case .addKeep, .addRemove, .updateRemove:
      #expect(returned.photo == nil)
    case .addReplace, .updateReplace:
      #expect(returned.photo?.thumbnail == Sample.cardPhoto(seed: 9).thumbnail)
    case .updateKeep:
      #expect(returned.photo?.thumbnail == Sample.cardPhoto(seed: 1).thumbnail)
    }
  }

  @Test(".replace 로 추가하면 썸네일·사진 id(makeID 두 번째 값)·압축본이 저장된다", arguments: StoreKind.allCases)
  func addWithReplace(kind: StoreKind) async throws {
    let store = try kind.make(makeID: IDSequence([Sample.id(1), Sample.id(2)]).next)
    let photo = Sample.cardPhoto(seed: 3)

    let added = try await store.add(Sample.draft(photo: .replace(photo)))

    #expect(added.id == Sample.id(1))
    #expect(added.photo == DDayPhoto(id: Sample.id(2), thumbnail: photo.thumbnail))
    #expect(try await store.fetchAll().first?.photo == added.photo)
    #expect(try await store.fetchPhoto(id: added.id) == photo.image)
  }

  @Test("추가에서 .keep·.remove 는 사진 없음이다", arguments: StoreKind.allCases, [DDayPhotoChange.keep, .remove])
  func addWithoutPhoto(kind: StoreKind, change: DDayPhotoChange) async throws {
    let store = try kind.make()

    let added = try await store.add(Sample.draft(photo: change))

    #expect(added.photo == nil)
    #expect(try await store.fetchAll().first?.photo == nil)
    #expect(try await store.fetchPhoto(id: added.id) == nil)
  }

  @Test("수정 .keep 은 사진 id·썸네일·압축본을 그대로 두고 제목만 바꾼다", arguments: StoreKind.allCases)
  func updateKeep(kind: StoreKind) async throws {
    let store = try kind.make()
    let photo = Sample.cardPhoto(seed: 1)
    let original = try await store.add(Sample.draft("처음", photo: .replace(photo)))

    let updated = try await store.update(id: original.id, Sample.draft("바뀜", photo: .keep))

    #expect(updated.title == "바뀜")
    #expect(updated.photo == original.photo)
    #expect(try await store.fetchAll().first?.photo == original.photo)
    #expect(try await store.fetchPhoto(id: original.id) == photo.image)
  }

  @Test("수정 .replace 는 새 사진 id·새 썸네일·새 압축본으로 바꾼다", arguments: StoreKind.allCases)
  func updateReplace(kind: StoreKind) async throws {
    let store = try kind.make()
    let original = try await store.add(Sample.draft(photo: .replace(Sample.cardPhoto(seed: 1))))
    let newPhoto = Sample.cardPhoto(seed: 2)

    let updated = try await store.update(id: original.id, Sample.draft(photo: .replace(newPhoto)))

    let originalPhotoID = try #require(original.photo?.id)
    let updatedPhoto = try #require(updated.photo)
    #expect(updatedPhoto.id != originalPhotoID)
    #expect(updatedPhoto.thumbnail == newPhoto.thumbnail)
    #expect(try await store.fetchAll().first?.photo == updatedPhoto)
    #expect(try await store.fetchPhoto(id: original.id) == newPhoto.image)
  }

  @Test("수정 .remove 는 사진을 지운다", arguments: StoreKind.allCases)
  func updateRemove(kind: StoreKind) async throws {
    let store = try kind.make()
    let original = try await store.add(Sample.draft(photo: .replace(Sample.cardPhoto())))

    let updated = try await store.update(id: original.id, Sample.draft(photo: .remove))

    #expect(updated.photo == nil)
    #expect(try await store.fetchAll().first?.photo == nil)
    #expect(try await store.fetchPhoto(id: original.id) == nil)
  }

  @Test("사진 있는 디데이를 지우면 fetchPhoto 가 notFound 다", arguments: StoreKind.allCases)
  func deleteRemovesPhoto(kind: StoreKind) async throws {
    let store = try kind.make()
    let original = try await store.add(Sample.draft(photo: .replace(Sample.cardPhoto())))

    try await store.delete(id: original.id)

    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.fetchPhoto(id: original.id)
    }
  }

  @Test("없는 id 의 fetchPhoto 는 notFound 다", arguments: StoreKind.allCases)
  func fetchPhotoNotFound(kind: StoreKind) async throws {
    let store = try kind.make()
    _ = try await store.add(Sample.draft(photo: .replace(Sample.cardPhoto())))

    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.fetchPhoto(id: Sample.id(99))
    }
  }

  @Test(".replace 추가는 id 를 두 개 쓰고, notFound 로 끝난 .replace 수정은 id·시각을 쓰지 않는다", arguments: StoreKind.allCases)
  func makeIDOrder(kind: StoreKind) async throws {
    let clock = TestClock(start: Date(timeIntervalSince1970: 100))
    let store = try kind.make(
      now: clock.next,
      makeID: IDSequence([Sample.id(1), Sample.id(2), Sample.id(3)]).next
    )

    let first = try await store.add(Sample.draft(photo: .replace(Sample.cardPhoto())))
    await #expect(throws: DDayStoreError.notFound) {
      _ = try await store.update(id: Sample.id(99), Sample.draft(photo: .replace(Sample.cardPhoto(seed: 1))))
    }
    let second = try await store.add(Sample.draft("둘째"))

    #expect(first.id == Sample.id(1))
    #expect(first.photo?.id == Sample.id(2))
    #expect(second.id == Sample.id(3))
    #expect(second.createdAt == first.createdAt.addingTimeInterval(1))
  }

  @Test("Fake: saveFailed 로 실패한 .replace 수정은 옛 사진·압축본을 남기고, loadFailed 는 fetchPhoto 도 실패시킨다")
  func fakeInjectedErrors() async throws {
    let store = DDayStoreClientFake(now: TestClock().next)
    let photo = Sample.cardPhoto(seed: 1)
    let original = try await store.add(Sample.draft("처음", photo: .replace(photo)))

    store.failNextCall(with: .saveFailed)
    await #expect(throws: DDayStoreError.saveFailed) {
      _ = try await store.update(id: original.id, Sample.draft("실패", photo: .replace(Sample.cardPhoto(seed: 2))))
    }
    #expect(store.dDays == [original])
    #expect(store.photoImages == [original.id: photo.image])
    #expect(try await store.fetchPhoto(id: original.id) == photo.image)

    store.failNextCall(with: .loadFailed)
    await #expect(throws: DDayStoreError.loadFailed) {
      _ = try await store.fetchPhoto(id: original.id)
    }
    #expect(try await store.fetchPhoto(id: original.id) == photo.image)
  }

  @Test("Fake: 처음 넣은 압축본을 사진 있는 디데이의 fetchPhoto 가 돌려주고, 사진 없는 디데이는 nil 이다")
  func fakeInitialPhotoImages() async throws {
    let withPhoto = DDay(
      id: Sample.id(1),
      title: "사진",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 10),
      updatedAt: Date(timeIntervalSince1970: 10),
      photo: DDayPhoto(id: Sample.id(11), thumbnail: Sample.cardPhoto().thumbnail)
    )
    let withoutPhoto = DDay(
      id: Sample.id(2),
      title: "없음",
      schedule: Sample.draft().schedule,
      reminder: .default,
      createdAt: Date(timeIntervalSince1970: 20),
      updatedAt: Date(timeIntervalSince1970: 20)
    )
    let image = Sample.cardPhoto().image
    let store = DDayStoreClientFake(
      dDays: [withPhoto, withoutPhoto],
      photoImages: [withPhoto.id: image, withoutPhoto.id: image]
    )

    #expect(try await store.fetchPhoto(id: withPhoto.id) == image)
    #expect(try await store.fetchPhoto(id: withoutPhoto.id) == nil)
  }
}
