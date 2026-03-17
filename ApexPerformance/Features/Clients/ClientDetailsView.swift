//
//  ClientDetails.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 24.12.2025..
//

import SwiftUI

import SwiftUI

struct ClientDetailsView: View {
    
    @EnvironmentObject private var toastManager: ToastManager
    
    let client: Client
    
    @State private var form: Client
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var lastPayment: Date = Date()
    @State private var daysUntilExpiration: Int = 0
    
    init(client: Client) {
        self.client = client
        self._form = State(initialValue: client)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                CardView {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(client.firstName) \(client.lastName)")
                                .font(.headline)
                            
                            Text(form.email ?? "no_email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                CardView(title: "personal_info") {
                    VStack(spacing: 0) {
                        editableRow(title: "first_name") {
                            TextField("first_name", text: $form.firstName)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider().padding(.leading, 0)
                        editableRow(title: "last_name") {
                            TextField("last_name", text: $form.lastName)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                CardView(title: "contact") {
                    VStack(spacing: 0) {
                        editableRow(title: "email") {
                            TextField(
                                "email",
                                text: Binding(
                                    get: { form.email ?? "" },
                                    set: { form.email = $0.isEmpty ? nil : $0 }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .multilineTextAlignment(.trailing)
                        }
                        Divider()
                        editableRow(title: "mobile_phone") {
                            TextField(
                                "mobile_phone",
                                text: Binding(
                                    get: { form.phone ?? "" },
                                    set: { form.phone = $0.isEmpty ? nil : $0 }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                let outOfCredits = (form.credits ?? 0) <= 0
                
                CardView(title: "credits") {
                    VStack(spacing: 0) {
                        editableRow(title: "appointments_left") {
                            TextField("appointments_left", value: Binding(
                                get: { form.credits ?? 0 },
                                set: { form.credits = $0 }
                            ), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(outOfCredits ? .body.weight(.bold) : .body)
                        }
                        
                        Divider().padding(.leading, 0)
                        editableRow(title: "Last Payment") {
                            Text(DateFormatter.dateAndTimeWithDots.string(from: form.lastCreditsIncrease ?? .now))
                                .font(outOfCredits ? .body.weight(.bold) : .body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                CardView(title: "body_measurements") {
                    if (form.bodyMeasurements ?? []).isEmpty {
                        Text("no_measurements")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 0) {
                            let measurements = (form.bodyMeasurements ?? [])
                                .sorted { $0.measuredAt > $1.measuredAt }
                            
                            ForEach(measurements) { bodyMeasurement in
                                NavigationLink {
                                    BodyMeasurementDetailsView(bodyMeasurement: bodyMeasurement)
                                } label: {
                                    SettingsRowView(
                                        icon: "ruler",
                                        iconTint: .blue,
                                        title: Text(DateFormatter.dateAndTimeWithDots.string(from: bodyMeasurement.measuredAt)),
                                        subtitle: nil,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                if bodyMeasurement.id != measurements.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(client.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    ZStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Text("Save")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .disabled(isSaving)
            }
        }
    }
    
    private func editableRow<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            field()
        }
        .padding(.vertical, 10)
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            _ = try await updateUser()
            toastManager.show(Text("successfully_updated_user"), type: ToastType.success)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage!), type: ToastType.error)
        }
    }
    
    private func updateUser() async throws -> Client {
        let url = AppEnvironment.apiURL.appendingPathComponent("clients/" + client.id.uuidString)
        let response: Client = try await APIClient.shared.request(url, method: HTTPMethod.put, body: JSONEncoder().encode(form))
        return response;
    }
}

#Preview("ClientDetailsView") {
    // Sample data for preview
    let sample = Client(
        id: UUID(),
        firstName: "Jane",
        lastName: "Doe",
        email: "jane.doe@example.com",
        phone: "+1 555 123 4567",
        credits: 0,
        bodyMeasurements: [
            BodyMeasurement(
                id: UUID(),
                height: 172,
                weight: 68,
                shoulders: 100,
                chest: 92,
                upperArm: 32,
                waist: 75,
                thigh: 55,
                calves: 38,
                glutes: 94,
                measuredAt: Date(),
                client: Client(id: UUID(), firstName: "Jane", lastName: "Doe", lastCreditsIncrease: .now)
            )
        ], lastCreditsIncrease: .now
    )
    NavigationStack {
        ClientDetailsView(client: sample)
            .environmentObject(ToastManager())
    }
}

