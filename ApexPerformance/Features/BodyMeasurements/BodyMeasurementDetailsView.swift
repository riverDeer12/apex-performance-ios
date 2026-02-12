import SwiftUI

struct BodyMeasurementDetailsView: View {
    let bodyMeasurement: BodyMeasurement
    
    @State private var form: BodyMeasurement
    
    init(bodyMeasurement: BodyMeasurement) {
        self.bodyMeasurement = bodyMeasurement
        self._form = State(initialValue: bodyMeasurement)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("body_measurements")
                        .font(.title.bold())
                    
                    Text(DateFormatter.dateAndTimeWithDots.string(from: bodyMeasurement.measuredAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                CardView(title: "measurements") {
                    VStack(spacing: 0) {
                        measurementRow("height", $form.height, unit: "cm")
                        divider()
                        measurementRow("weight", $form.weight, unit: "kg")
                        divider()
                        measurementRow("shoulders", $form.shoulders, unit: "cm")
                        divider()
                        measurementRow("chest", $form.chest, unit: "cm")
                        divider()
                        measurementRow("upper_arm", $form.upperArm, unit: "cm")
                        divider()
                        measurementRow("waist", $form.waist, unit: "cm")
                        divider()
                        measurementRow("thigh", $form.thigh, unit: "cm")
                        divider()
                        measurementRow("calves", $form.calves, unit: "cm")
                        divider()
                        measurementRow("glutes", $form.glutes, unit: "cm")
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 12)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("measurements")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func divider() -> some View {
        Divider()
            .padding(.leading, 0)
    }
    
    private func measurementRow(
        _ title: String,
        _ binding: Binding<Decimal>,
        unit: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                TextField("",
                          value: binding,
                          format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(minWidth: 60) // keeps alignment consistent
                
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}
#Preview("BodyMeasurementDetailsView") {
    // Sample data for preview
    let sampleClient = Client(id: UUID(), firstName: "Preview", lastName: "Client")
    let sample = BodyMeasurement(
        id: UUID(),
        height: 180,
        weight: 80,
        shoulders: 110,
        chest: 100,
        upperArm: 36,
        waist: 82,
        thigh: 58,
        calves: 40,
        glutes: 98,
        measuredAt: Date(),
        client: sampleClient
    )
    NavigationStack {
        BodyMeasurementDetailsView(bodyMeasurement: sample)
    }
}

