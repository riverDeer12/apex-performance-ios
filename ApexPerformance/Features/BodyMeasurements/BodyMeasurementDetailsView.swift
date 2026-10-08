import SwiftUI

struct BodyMeasurementDetailsView: View {
    let bodyMeasurement: BodyMeasurement
    let isEditable: Bool
    // Set for staff, shows the delete button.
    var onDeleted: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var form: BodyMeasurement
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteDialog = false

    init(bodyMeasurement: BodyMeasurement, isEditable: Bool = true, onDeleted: ((UUID) -> Void)? = nil) {
        self.bodyMeasurement = bodyMeasurement
        self.isEditable = isEditable
        self.onDeleted = onDeleted
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
                
                if isEditable && onDeleted != nil {
                    Button {
                        showDeleteDialog = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("delete_measurement")
                        }
                    }
                    .buttonStyle(ApexDestructiveButtonStyle())
                    .disabled(isDeleting || isSaving)
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 12)
            }
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationTitle("measurements")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("delete_measurement_question", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task { await deleteBodyMeasurement() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("can_not_be_undone")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
            if isEditable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await updateBodyMeasurement() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("save")
                    .disabled(isSaving)
                }
            }
        }
    }
    
    @MainActor
    private func deleteBodyMeasurement() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            let url = AppEnvironment.apiURL
                .appendingPathComponent("body-measurements")
                .appendingPathComponent(bodyMeasurement.id.uuidString)
            try await APIClient.shared.requestData(url, method: .delete)
            onDeleted?(bodyMeasurement.id)
            toastManager.show("body_measurement_deleted_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
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
            Text(LocalizedStringKey(title))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                if isEditable {
                    NumberWheelField(
                        value: binding.zeroAsEmpty,
                        range: BodyMeasurement.wheel(for: title).range,
                        step: 0.1,
                        defaultValue: BodyMeasurement.wheel(for: title).start,
                        title: LocalizedStringKey(title)
                    )
                } else {
                    Text(binding.wrappedValue, format: .number)
                        .fontWeight(.semibold)
                }

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
    
    private func updateBodyMeasurement() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            try await sendUpdateToAPI()
            toastManager.show("body_measurement_updated_successfully", type: .success)
            dismiss()
        } catch {
            let errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage), type: .error)
        }
    }
    
    private func sendUpdateToAPI() async throws {
        struct UpdateBodyMeasurementRequest: Encodable {
            let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
        }
        
        let url = AppEnvironment.apiURL
            .appendingPathComponent("body-measurements")
            .appendingPathComponent(bodyMeasurement.id.uuidString)
        
        let request = UpdateBodyMeasurementRequest(
            height: form.height,
            weight: form.weight,
            shoulders: form.shoulders,
            chest: form.chest,
            upperArm: form.upperArm,
            waist: form.waist,
            thigh: form.thigh,
            calves: form.calves,
            glutes: form.glutes
        )
        
        _ = try await APIClient.shared.request(
            url,
            method: .put,
            body: JSONEncoder().encode(request)
        ) as StatusResponse
    }
}
#Preview("BodyMeasurementDetailsView") {
    // Sample data for preview
    let sampleClient = Client(id: UUID(), firstName: "Preview", lastName: "Client", lastCreditsIncrease: .now)
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
            .environmentObject(ToastManager())
    }
}

