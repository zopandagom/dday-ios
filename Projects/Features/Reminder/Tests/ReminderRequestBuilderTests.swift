import Core
import DDayStoreInterface
import Foundation
import LocalNotificationInterface
import Testing
@testable import ReminderFeature

/// 요청 목록 계산. 본문은 언어와 무관한 함수(`"\(kind)"`)를 주입해 문구 종류를 본다.
struct ReminderRequestBuilderTests {
  func requests(_ dDays: [DDay], now: TimeOfDay = ReminderSample.time(8, 0)) -> [NotificationRequest] {
    ReminderRequestBuilder.requests(for: dDays, today: ReminderSample.today, now: now, body: { "\($0)" })
  }

  func kind(_ kind: ReminderMessageKind) -> String {
    "\(kind)"
  }

  @Test("D-day 방식: 식별자·디데이 id·제목·본문 종류·날짜·시각")
  func dDayTarget() {
    let exam = ReminderSample.exam
    let expected = [
      (7, ReminderSample.day(2027, 3, 1)),
      (2, ReminderSample.day(2027, 3, 6)),
      (0, ReminderSample.day(2027, 3, 8)),
    ]
    .map { daysBefore, day in
      NotificationRequest(
        id: "dday.reminder.\(exam.id.uuidString).2027-03-08.\(daysBefore)",
        dDayID: exam.id,
        title: "시험",
        body: self.kind(.target(daysBefore: daysBefore)),
        day: day,
        time: .defaultReminderTime
      )
    }
    #expect(self.requests([exam]) == expected)
  }

  @Test("매년 D-day: 다음 두 날짜 모두 목표일 문구")
  func yearlyTargetTwoOccurrences() {
    let birthday = ReminderSample.dDay(
      2,
      title: "생일",
      on: ReminderSample.day(2026, 3, 10),
      repeatRule: .yearly,
      reminder: ReminderSample.reminder([0], time: ReminderSample.time(10, 30))
    )
    let result = self.requests([birthday])
    #expect(result.map(\.day) == [ReminderSample.day(2027, 3, 10), ReminderSample.day(2028, 3, 10)])
    #expect(result.map(\.body) == [self.kind(.target(daysBefore: 0)), self.kind(.target(daysBefore: 0))])
    #expect(result.map(\.time) == [ReminderSample.time(10, 30), ReminderSample.time(10, 30)])
    #expect(result.map(\.id) == [
      "dday.reminder.\(birthday.id.uuidString).2027-03-10.0",
      "dday.reminder.\(birthday.id.uuidString).2028-03-10.0",
    ])
  }

  @Test("D+ 방식: 시작일·100일 단위·주년 문구")
  func dPlusKinds() throws {
    let start = ReminderSample.day(2027, 3, 3)
    let couple = ReminderSample.dDay(
      3,
      title: "사귄 날",
      on: start,
      counting: .dPlus,
      reminder: ReminderSample.reminder([0])
    )
    let result = self.requests([couple])

    #expect(result.map(\.body) == [
      self.kind(.start(daysBefore: 0)),
      self.kind(.daysSince(100, daysBefore: 0)),
      self.kind(.daysSince(200, daysBefore: 0)),
      self.kind(.anniversary(years: 1, daysBefore: 0)),
      self.kind(.anniversary(years: 2, daysBefore: 0)),
    ])
    #expect(try result.map(\.day) == [
      start,
      #require(start.adding(days: 100)),
      #require(start.adding(days: 200)),
      ReminderSample.day(2028, 3, 3),
      ReminderSample.day(2029, 3, 3),
    ])
    #expect(result.allSatisfy { $0.dDayID == couple.id && $0.title == "사귄 날" })
  }

  @Test("1일째 방식: 미래 시작일과 n일째 문구 (N일 전)")
  func dayOneKinds() throws {
    let start = ReminderSample.day(2027, 3, 5)
    let dDay = ReminderSample.dDay(
      4,
      on: start,
      counting: .dayOne,
      reminder: ReminderSample.reminder([2], anniversaries: false)
    )
    let result = self.requests([dDay])

    #expect(result.map(\.body) == [
      self.kind(.start(daysBefore: 2)),
      self.kind(.dayCount(100, daysBefore: 2)),
      self.kind(.dayCount(200, daysBefore: 2)),
    ])
    // 100일째 = 시작일 + 99, 그 2일 전에 울린다.
    #expect(try result.map(\.day) == [
      #require(start.adding(days: -2)),
      #require(start.adding(days: 97)),
      #require(start.adding(days: 197)),
    ])
    let hundredthDay = start.adding(days: 99)?.description ?? ""
    #expect(result[1].id == "dday.reminder.\(dDay.id.uuidString).\(hundredthDay).2")
  }

  @Test("제목은 저장된 그대로 (빈 제목도 바꾸지 않는다)")
  func titleAsStored() {
    let empty = ReminderSample.dDay(
      5,
      title: "",
      on: ReminderSample.day(2027, 3, 8),
      reminder: ReminderSample.reminder([0])
    )
    let long = ReminderSample.dDay(
      6,
      title: String(repeating: "아주 긴 제목 ", count: 20),
      on: ReminderSample.day(2027, 3, 9),
      reminder: ReminderSample.reminder([0])
    )
    let result = self.requests([empty, long])
    #expect(result.map(\.title) == ["", long.title])
    #expect(result.allSatisfy { !$0.body.isEmpty })
  }

  @Test("알림을 끈 디데이·지난 디데이·지난 시각은 없다")
  func excludesDisabledAndPast() {
    let disabled = ReminderSample.dDay(
      7,
      on: ReminderSample.day(2027, 3, 8),
      reminder: ReminderSample.reminder(isEnabled: false)
    )
    let past = ReminderSample.dDay(8, on: ReminderSample.day(2027, 2, 20))
    let todayAtNine = ReminderSample.dDay(9, on: ReminderSample.today, reminder: ReminderSample.reminder([0]))

    #expect(self.requests([disabled, past]).isEmpty)
    #expect(self.requests([todayAtNine], now: ReminderSample.time(8, 59)).count == 1)
    #expect(self.requests([todayAtNine], now: ReminderSample.time(9, 0)).isEmpty)
  }

  @Test("가까운 순 최대 60개 (계획기 한도)")
  func limitsToSixty() {
    let dDays = (0 ..< 30).map { index in
      ReminderSample.dDay(
        100 + index,
        on: ReminderSample.day(2027, 5, 1).adding(days: index) ?? ReminderSample.today,
        reminder: ReminderSample.reminder([0, 2, 7, 30])
      )
    }
    let result = self.requests(dDays)
    #expect(result.count == NotificationPlanner.maximumCount)
    #expect(result.map(\.day) == result.map(\.day).sorted())
    #expect(Set(result.map(\.id)).count == result.count)
  }
}
