import Core
import CoreGraphics
import DDayStoreInterface
import DDayStoreTesting
import Foundation
import PhotoInterface
import PhotoTesting
@testable import DDayEditorFeature

/// 테스트 값 만들기. 테스트라 강제 언래핑을 쓴다.
enum EditorSample {
  static let today = EditorSample.day(2026, 11, 26)
  static let originalID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
  static let createdAt = Date(timeIntervalSince1970: 100)

  static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
    CalendarDay(year: year, month: month, day: day)!
  }

  static func lunar(_ year: Int, _ month: Int, _ day: Int, leap: Bool = false) -> LunarDate {
    LunarDate(year: year, month: month, day: day, isLeapMonth: leap)
  }

  static func time(_ hour: Int, _ minute: Int) -> TimeOfDay {
    TimeOfDay(hour: hour, minute: minute)!
  }

  /// 저장된 디데이 (id 고정).
  static func dDay(
    title: String = "엄마 생일",
    date: DDayDate = .solar(EditorSample.day(2027, 3, 14)),
    repeatRule: RepeatRule = .yearly,
    countingStyle: CountingStyle = .dDay,
    reminder: ReminderSettings = ReminderSettings(
      isEnabled: true,
      enabledDaysBefore: [0, 30],
      time: EditorSample.time(20, 30)
    ),
    photo: DDayPhoto? = nil
  ) -> DDay {
    DDay(
      id: self.originalID,
      title: title,
      schedule: DDaySchedule(date: date, repeatRule: repeatRule, countingStyle: countingStyle),
      reminder: reminder,
      createdAt: self.createdAt,
      updatedAt: self.createdAt,
      photo: photo
    )
  }

  /// 저장된 사진 (id 고정).
  static let storedPhotoID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
  static let storedPhoto = DDayPhoto(id: EditorSample.storedPhotoID, thumbnail: Data([0xAA]))

  /// 사진 있는 저장된 디데이와 그 압축본이 든 Fake.
  static func photoFake(_ dDay: DDay = EditorSample.dDay(photo: EditorSample.storedPhoto)) -> DDayStoreClientFake {
    DDayStoreClientFake(dDays: [dDay], photoImages: [dDay.id: Data([0xAB])])
  }

  /// 고른 사진: 400×300 샘플 JPEG 을 돌려준다.
  static let pickedJPEG = PickedPhoto { PhotoSamples.jpegData(width: 400, height: 300) }
  /// 읽기에 실패하는 고른 사진.
  static let unreadable = PickedPhoto { () throws(PhotoError) -> Data in throw .readFailed }
  /// 아무 데이터도 읽지 않는 고른 사진 (Controlled 클라이언트용).
  static let anyPicked = PickedPhoto { Data() }

  /// 작업 이미지 (단색 CGImage).
  static func workingImage(width: Int = 300, height: Int = 200) -> PhotoWorkingImage {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return PhotoWorkingImage(image: context.makeImage()!)
  }

  static func cardPhoto(_ seed: UInt8 = 1) -> CardPhoto {
    CardPhoto(image: Data([seed, 0x01]), thumbnail: Data([seed, 0x02]))
  }
}

/// `onFinished` 로 받은 결과.
@MainActor
final class OutcomeRecorder {
  var outcomes: [DDayEditorOutcome] = []
}

@MainActor
func makeEditor(
  _ mode: DDayEditorMode,
  store: any DDayStoreClient = DDayStoreClientFake(),
  photoClient: any PhotoClient = PhotoClientFake(),
  today: CalendarDay = EditorSample.today,
  recorder: OutcomeRecorder = OutcomeRecorder()
) -> DDayEditorModel {
  DDayEditorModel(
    mode: mode,
    store: store,
    photoClient: photoClient,
    today: today,
    onFinished: { recorder.outcomes.append($0) }
  )
}

/// 수정 모드 모델과 그 디데이가 든 Fake.
@MainActor
func makeEditEditor(
  _ dDay: DDay = EditorSample.dDay(),
  recorder: OutcomeRecorder = OutcomeRecorder()
) -> (DDayEditorModel, DDayStoreClientFake) {
  let fake = DDayStoreClientFake(dDays: [dDay])
  return (makeEditor(.edit(dDay), store: fake, recorder: recorder), fake)
}

extension DDayEditorModel.EditorPhoto {
  /// 이번에 만든 사진이면 그 값.
  var newPhoto: CardPhoto? {
    if case let .new(cardPhoto) = self {
      return cardPhoto
    }
    return nil
  }
}
