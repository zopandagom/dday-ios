import Core
import Foundation

/// Example 의 "오늘". "하루 뒤로" 버튼으로 하루씩 미뤄 재정렬을 손으로 확인한다.
/// App 이 하나를 소유하고, 모델의 `today` 클로저가 이 인스턴스를 잡는다.
@MainActor
final class ExampleClock {
  private(set) var offsetDays = 0

  func today() -> CalendarDay {
    let base = CalendarDay(Date(), in: .autoupdatingCurrent)
    return base.adding(days: self.offsetDays) ?? base
  }

  func advanceOneDay() {
    self.offsetDays += 1
  }
}
