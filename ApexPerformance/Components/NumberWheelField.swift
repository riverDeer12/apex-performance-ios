//
//  NumberWheelField.swift
//  ApexPerformance
//

import SwiftUI

/// Number shown like a field; tapping it opens wheel pickers to choose
/// the value instead of typing it: whole numbers on one wheel and,
/// for decimals, the fraction (e.g. ,0 ,5 or ,1 ... ,9) on the other.
struct NumberWheelField: View {
    @Binding var value: Decimal?
    let range: ClosedRange<Int>
    // 1 for whole numbers, 0.5 or 0.1 for decimals.
    var step: Decimal = 1
    var unit: String? = nil
    // Value the wheels start at when there is no value yet.
    var defaultValue: Decimal? = nil
    // Shows "Clear" so the value can be removed (e.g. a set without weight).
    var allowsEmpty = false
    var title: LocalizedStringKey? = nil
    // Text shown instead of the number, e.g. reps written as "8-10".
    var displayText: String? = nil

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Text(verbatim: displayText ?? value.map { Self.format($0, step: step) } ?? "—")
                .monospacedDigit()
                .foregroundStyle(value == nil && displayText == nil ? Color.secondary : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 44)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.borderless)
        .sheet(isPresented: $isPresented) {
            NumberWheelSheet(
                value: $value,
                range: range,
                step: step,
                unit: unit,
                defaultValue: defaultValue,
                allowsEmpty: allowsEmpty,
                title: title
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }

    static func format(_ value: Decimal, step: Decimal) -> String {
        let digits = step >= 1 ? 0 : 1
        return NSDecimalNumber(decimal: value).doubleValue
            .formatted(.number.precision(.fractionLength(0...digits)))
    }
}

/// Bottom sheet with the wheels.
private struct NumberWheelSheet: View {
    @Binding var value: Decimal?
    let range: ClosedRange<Int>
    let step: Decimal
    let unit: String?
    let defaultValue: Decimal?
    let allowsEmpty: Bool
    let title: LocalizedStringKey?

    @Environment(\.dismiss) private var dismiss

    @State private var whole: Int
    // Index of the fraction: 0 = ,0, 1 = ,5 (step 0.5) or ,1 (step 0.1)...
    @State private var fraction: Int

    init(value: Binding<Decimal?>, range: ClosedRange<Int>, step: Decimal, unit: String?,
         defaultValue: Decimal?, allowsEmpty: Bool, title: LocalizedStringKey?) {
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.defaultValue = defaultValue
        self.allowsEmpty = allowsEmpty
        self.title = title

        let start = NSDecimalNumber(decimal: value.wrappedValue ?? defaultValue ?? Decimal(range.lowerBound))
            .doubleValue
        let clamped = min(max(start, Double(range.lowerBound)), Double(range.upperBound))
        let wholePart = Int(clamped.rounded(.down))
        let stepValue = NSDecimalNumber(decimal: step).doubleValue
        let fractionIndex = stepValue < 1 ? Int(((clamped - Double(wholePart)) / stepValue).rounded()) : 0
        _whole = State(initialValue: wholePart)
        _fraction = State(initialValue: fractionIndex)
    }

    private var fractionCount: Int {
        step >= 1 ? 1 : Int(NSDecimalNumber(decimal: 1 / step).doubleValue.rounded())
    }

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? ","
    }

    private var selectedValue: Decimal {
        Decimal(whole) + Decimal(fraction) * step
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker(selection: $whole) {
                    ForEach(Array(range), id: \.self) { number in
                        Text(verbatim: "\(number)").tag(number)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.wheel)

                if fractionCount > 1 {
                    Picker(selection: $fraction) {
                        ForEach(0..<fractionCount, id: \.self) { index in
                            Text(verbatim: "\(decimalSeparator)\(fractionDigits(index))").tag(index)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90)
                }

                if let unit {
                    Text(verbatim: unit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 20)
                }
            }
            .padding(.horizontal, 12)
            .navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        value = selectedValue
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                if allowsEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("clear", role: .destructive) {
                            value = nil
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // ",5" for step 0.5, ",3" for step 0.1.
    private func fractionDigits(_ index: Int) -> String {
        let fractionValue = NSDecimalNumber(decimal: Decimal(index) * step).doubleValue
        return String(Int((fractionValue * 10).rounded()))
    }
}

extension Binding where Value == Decimal {
    /// Optional view of a number where 0 means "not entered yet".
    var zeroAsEmpty: Binding<Decimal?> {
        Binding<Decimal?>(
            get: { wrappedValue == 0 ? nil : wrappedValue },
            set: { wrappedValue = $0 ?? 0 }
        )
    }
}

extension Binding where Value == Int? {
    /// Whole number as a decimal for the wheels.
    var asDecimal: Binding<Decimal?> {
        Binding<Decimal?>(
            get: { wrappedValue.map { Decimal($0) } },
            set: { wrappedValue = $0.map { NSDecimalNumber(decimal: $0).intValue } }
        )
    }
}

#Preview {
    struct Demo: View {
        @State var weight: Decimal? = 72.5
        @State var reps: Decimal? = nil
        var body: some View {
            Form {
                HStack {
                    Text("weight")
                    Spacer()
                    NumberWheelField(value: $weight, range: 0...300, step: 0.5, unit: "kg")
                }
                HStack {
                    Text("reps")
                    Spacer()
                    NumberWheelField(value: $reps, range: 1...100, allowsEmpty: true)
                }
            }
        }
    }
    return Demo()
}
