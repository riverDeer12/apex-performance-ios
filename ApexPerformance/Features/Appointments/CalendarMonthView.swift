//
//  CalendarMonthView.swift
//  ApexPerformance
//

import SwiftUI

struct CalendarMonthView: View {

    @Binding var selectedDate: Date
    var approvedDates: Set<Date> = []
    var pendingDates: Set<Date> = []

    @State private var displayedMonth: Date

    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>, approvedDates: Set<Date> = [], pendingDates: Set<Date> = []) {
        self._selectedDate = selectedDate
        self.approvedDates = approvedDates
        self.pendingDates = pendingDates
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    // Weekday symbols reordered to start on the calendar's locale-aware first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    // Six-ish rows of 7 days, with nil placeholders for the leading/trailing days
    // that belong to adjacent months.
    private var weeks: [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var days: [Date?] = []
        var cursor = firstWeek.start
        while cursor < monthInterval.start {
            days.append(nil)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? monthInterval.start
        }
        for offset in 0..<daysInMonth {
            if let day = calendar.date(byAdding: .day, value: offset, to: monthInterval.start) {
                days.append(day)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.apexMainColor)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.apexMainColor)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            dayCell(day)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            if !calendar.isDate(newValue, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newValue
            }
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(day)
            let dayStart = calendar.startOfDay(for: day)
            let hasApproved = approvedDates.contains(dayStart)
            let hasPending = pendingDates.contains(dayStart)

            Button {
                selectedDate = day
            } label: {
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.subheadline.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white : (isToday ? Color.apexMainColor : .primary))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(isSelected ? Color.apexMainColor : Color.clear)
                        )
                        .overlay(
                            Circle().stroke(isToday && !isSelected ? Color.apexMainColor : .clear, lineWidth: 1)
                        )

                    HStack(spacing: 3) {
                        if hasApproved {
                            Circle().fill(Color.apexMainColor).frame(width: 5, height: 5)
                        }
                        if hasPending {
                            Circle().fill(Color.orange).frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 41)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selectedDate = Date()
        var body: some View {
            let today = Calendar.current.startOfDay(for: Date())
            return CalendarMonthView(
                selectedDate: $selectedDate,
                approvedDates: [today, Calendar.current.date(byAdding: .day, value: 3, to: today)!],
                pendingDates: [Calendar.current.date(byAdding: .day, value: 1, to: today)!]
            )
            .padding()
        }
    }
    return PreviewWrapper()
}
