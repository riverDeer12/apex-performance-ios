//
//  CreateBodyMeasurementView.swift
//  ApexPerformance
//
//  Created by Sara Husidic on 3/23/26.
//

import SwiftUI

struct CreateBodyMeasurementView: View {
    let client: Client
    var onSuccess: (() -> Void)? = nil
    
    /// Optional binding to control the presentation of this view.
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
                Form {
                    Section(header: Text("Body Measurements")) {
                        measurementField("height", value: $height, unit: "cm")
                        measurementField("weight", value: $weight, unit: "kg")
                        measurementField("shoulders", value: $shoulders, unit: "cm")
                        measurementField("chest", value: $chest, unit: "cm")
                        measurementField("upper_arm", value: $upperArm, unit: "cm")
                        measurementField("waist", value: $waist, unit: "cm")
                        measurementField("thigh", value: $thigh, unit: "cm")
                        measurementField("calves", value: $calves, unit: "cm")
                        measurementField("glutes", value: $glutes, unit: "cm")
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .navigationTitle("new_body_measurement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await save() }
                        } label: {
                            ZStack {
                                if isSaving {
                                    ProgressView().scaleEffect(0.9)
                                } else {
                                    Text("Save")
                                }
                            }
                        }
                        .disabled(isSaving)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
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
    
    @ViewBuilder
    private func measurementField(_ title: LocalizedStringKey, value: Binding<Decimal>, unit: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            TextField("", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(minWidth: 60)
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }.padding(.vertical, 10)
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await sendBodyMeasurementToAPI()
            toastManager.show(Text("body_measurement_created_successfully"), type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isPresented = false
                if let onSuccess = onSuccess {
                    onSuccess()
                } else {
                    dismiss()
                }
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage ?? "unknown_error_message"), type: .error)
        }
    }
    
    private func sendBodyMeasurementToAPI() async throws {
        struct CreateBodyMeasurementRequest: Encodable {
            let clientId: UUID
            let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
        }
        let url = AppEnvironment.apiURL.appendingPathComponent("body-measurements")
        let request = CreateBodyMeasurementRequest(
            clientId: client.id,
            height: height, weight: weight, shoulders: shoulders, chest: chest,
            upperArm: upperArm, waist: waist, thigh: thigh, calves: calves, glutes: glutes
        )
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
