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
                                TextField("", value: $height, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("weight").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $weight, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("kg").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("shoulders").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $shoulders, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("chest").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $chest, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("upper_arm").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $upperArm, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("waist").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $waist, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("thigh").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $thigh, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("calves").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $calves, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
                                Text("cm").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 8)
                            Divider()
                            HStack {
                                Text("glutes").foregroundStyle(.secondary)
                                Spacer()
                                TextField("", value: $glutes, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(minWidth: 60)
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

