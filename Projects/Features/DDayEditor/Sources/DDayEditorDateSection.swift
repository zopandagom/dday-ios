import Core
import SwiftUI

/// 편집 화면의 날짜 섹션: 양력·음력 선택과 변환 날짜 표시.
struct DDayEditorDateSection: View {
  let model: DDayEditorModel
  @Environment(\.timeZone) private var timeZone
  @Environment(\.locale) private var locale

  var body: some View {
    Section {
      Picker(selection: Binding(
        get: { self.model.calendarKind },
        set: { self.model.calendarKindChanged($0) }
      )) {
        ForEach(DDayEditorModel.CalendarKind.allCases, id: \.self) { kind in
          Text(DDayEditorText.calendarKind(kind)).tag(kind)
        }
      } label: {
        Text(DDayEditorText.dateSection)
      }
      .pickerStyle(.segmented)

      switch self.model.date {
      case let .solar(day):
        self.solarPicker(day)
      case let .lunar(lunar):
        self.lunarPickers(lunar)
      }

      if let converted = DDayEditorText.convertedDateText(self.model.date, locale: self.locale) {
        Text(verbatim: converted)
          .foregroundStyle(.secondary)
      }
    } header: {
      Text(DDayEditorText.dateSection)
    } footer: {
      if self.model.isDateAdjusted {
        Text(DDayEditorText.dateAdjusted)
      }
    }
  }

  private func solarPicker(_ day: CalendarDay) -> some View {
    let range = KoreanLunarCalendar.supportedSolarRange
    let bounds = EditorDateConversion.date(from: range.lowerBound, in: self.timeZone)
      ... EditorDateConversion.date(from: range.upperBound, in: self.timeZone)
    return DatePicker(
      selection: Binding(
        get: { EditorDateConversion.date(from: day, in: self.timeZone) },
        set: { self.model.solarDayChanged(EditorDateConversion.calendarDay(from: $0, in: self.timeZone)) }
      ),
      in: bounds,
      displayedComponents: .date
    ) {
      Text(DDayEditorText.dateSection)
    }
  }

  @ViewBuilder
  private func lunarPickers(_ lunar: LunarDate) -> some View {
    let choices = self.model.lunarChoices
    Picker(selection: Binding(get: { lunar.year }, set: { self.model.lunarYearChanged($0) })) {
      ForEach(Array(choices.years), id: \.self) { year in
        Text(DDayEditorText.yearValue(year)).tag(year)
      }
    } label: {
      Text(DDayEditorText.lunarYear)
    }
    .pickerStyle(.menu)

    Picker(selection: Binding(get: { lunar.month }, set: { self.model.lunarMonthChanged($0) })) {
      ForEach(choices.months, id: \.self) { month in
        Text(DDayEditorText.monthValue(month)).tag(month)
      }
    } label: {
      Text(DDayEditorText.lunarMonth)
    }
    .pickerStyle(.menu)

    if choices.leapMonth == lunar.month {
      Toggle(isOn: Binding(get: { lunar.isLeapMonth }, set: { self.model.lunarLeapMonthChanged($0) })) {
        Text(DDayEditorText.lunarLeapMonth)
      }
    }

    Picker(selection: Binding(get: { lunar.day }, set: { self.model.lunarDayChanged($0) })) {
      ForEach(Array(choices.days), id: \.self) { day in
        Text(DDayEditorText.dayValue(day)).tag(day)
      }
    } label: {
      Text(DDayEditorText.lunarDay)
    }
    .pickerStyle(.menu)
  }
}
