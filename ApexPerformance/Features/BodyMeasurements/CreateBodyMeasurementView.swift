import SwiftUI

struct CreateBodyMeasurementView: View {
    let client: Client
    var onSuccess: (() -> Void)? = nil
    
    @Binding var isPresented: Bool?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var toastManager: ToastManager
    
    // Body measurement fields (initialize empty)
    @State private var height: Decimal = 0
    @State private var weight: Decimal = 0
    @State private var shoulders: Decimal = 0
    @State private var chest: Decimal = 0
    @State private var upperArm: Decimal = 0
    @State private var waist: Decimal = 0
    @State private var thigh: Decimal = 0
    @State private var calves: Decimal = 0
    @State private var glutes: Decimal = 0
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(client: Client, onSuccess: (() -> Void)? = nil, isPresented: Binding<Bool?> = .constant(nil)) {
        self.client = client
        self.onSuccess = onSuccess
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        Group {
                            HStack {
                                Text("height").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $height.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "height").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "height").start,
                                    title: "height"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("weight").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $weight.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "weight").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "weight").start,
                                    title: "weight"
                                )
                                Text("kg").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("shoulders").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $shoulders.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "shoulders").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "shoulders").start,
                                    title: "shoulders"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("chest").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $chest.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "chest").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "chest").start,
                                    title: "chest"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("upper_arm").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $upperArm.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "upper_arm").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "upper_arm").start,
                                    title: "upper_arm"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("waist").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $waist.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "waist").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "waist").start,
                                    title: "waist"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("thigh").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $thigh.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "thigh").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "thigh").start,
                                    title: "thigh"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("calves").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $calves.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "calves").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "calves").start,
                                    title: "calves"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("glutes").foregroundStyle(.secondary)
                                Spacer()
                                NumberWheelField(
                                    value: $glutes.zeroAsEmpty,
                                    range: BodyMeasurement.wheel(for: "glutes").range,
                                    step: 0.1,
                                    defaultValue: BodyMeasurement.wheel(for: "glutes").start,
                                    title: "glutes"
                                )
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                        }
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding(.top, 10)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
                    )
                    .padding([.horizontal, .top])
                }
                .navigationTitle("new_body_measurement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            
            if isSaving {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.3)
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await sendBodyMeasurementToAPI()
            
            toastManager.show("body_measurement_created_successfully", type: .success)
            
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                isPresented = false
                
                if let onSuccess = onSuccess {
                    onSuccess()
                } else {
                    dismiss()
                }
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: .error)
        }
    }
    
    private func sendBodyMeasurementToAPI() async throws {
        
        struct CreateBodyMeasurementRequest: Encodable {
            let client: UUID
            let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
        }
        
        let url = AppEnvironment.apiURL.appendingPathComponent("body-measurements")
        
        let request = CreateBodyMeasurementRequest(
            client: client.id,
            height: height, weight: weight, shoulders: shoulders, chest: chest,
            upperArm: upperArm, waist: waist, thigh: thigh, calves: calves, glutes: glutes
        )
        
        let encoder = JSONEncoder()
        
        encoder.outputFormatting = .prettyPrinted
        
        _ = try await APIClient.shared.request(url, method: .post, body: JSONEncoder().encode(request)) as StatusResponse
    }
}

#Preview {
    CreateBodyMeasurementView(
        client: Client(id: UUID(), firstName: "Test", lastName: "User"),
        isPresented: .constant(nil)
    )
    .environmentObject(ToastManager())
}

