//
//  AppointmentDetailsView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 31.12.2025..
//

import SwiftUI

struct AppointmentDetailsView: View {
    
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    
    let appointment: Appointment
    
    @State private var showCancelRequestDialog = false
    @State private var showCancelConfirmation = false
    @State private var errorMessage: String?
    
    @State private var cancelationComment: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("appointment")
                        .font(.title2.bold())
                    
                    Text("manage_appointment_details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Top info card (like profile card)
                CardView {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 56, height: 56)
                            Image(systemName: "calendar")
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(Color.apexMainColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(DateFormatter.dateWithDots.string(from: appointment.startTime))
                                .font(.headline)
                            
                            Text("date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    StatTileView(value: DateFormatter.dayName.string(from: appointment.startTime), label: "day")
                    StatTileView(value: appointment.timeSlot.description ?? "unknown_value", label: "time_slot")
                }
                .padding(.horizontal, 20)
                
                // Clients card (like settings list)
                CardView(title: "clients") {
                        VStack(spacing: 0) {
                            ForEach(appointment.clients) { client in
                                SettingsRowView(
                                    icon: "person",
                                    iconTint: Color.apexMainColor,
                                    title: Text("\(client.firstName) \(client.lastName)"),
                                    subtitle: nil,
                                    showChevron: false
                                )
                                if client.id != appointment.clients.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                }
                .padding(.horizontal, 20)
                
                // Actions card
                
                if(!appointment.isCompleted){
                    CardView(title: "actions") {
                        VStack(spacing: 0) {
                            if(!authManager.hasRole(role: "Client")){
                                Button {
                                    showCancelRequestDialog = true
                                } label: {
                                    SettingsRowView(
                                        icon: "paperplane",
                                        iconTint: Color.apexMainColor,
                                        title: Text("send_cancelation_request"),
                                        subtitle: Text("notify_coach_about_cancelation"),
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if(!authManager.hasRole(role: "Client")){
                                Divider().padding(.leading, 52)
                                
                                Button(role: .destructive) {
                                    showCancelConfirmation = true
                                } label: {
                                    SettingsRowView(
                                        icon: "xmark.circle",
                                        iconTint: .red,
                                        title: Text("cancel_appointment"),
                                        subtitle: Text("cancel_appointment_info"),
                                        showChevron: true,
                                        titleColor: .red
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 12)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("cancel_appointment_question", isPresented: $showCancelConfirmation) {
            Button("cancel_appointment", role: .destructive) {
                Task { await cancelAppointment() }
            }
            Button("keep", role: .cancel) {}
        } message: {
            Text("can_not_be_undone")
        }
        .sheet(isPresented: $showCancelRequestDialog) {
            VStack(spacing: 10) {
                
                Spacer()
                
                Text("confirm_your_action")
                    .font(.headline)
                
                Text("write_comment_for_cancelation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                
                TextAreaView(placeholder: "cancelation_comment_placeholder",
                             text: $cancelationComment)
                
                
                HStack {
                    Button {
                        Task { await sendCancelation() }
                        showCancelRequestDialog = false
                    } label: {
                        ButtonContentView("send_request", style: .textWithIcon(systemName: "paperplane"))
                    }
                }
            }
            .padding()
            .presentationDetents([.height(220)])
        }
    }
    
    private func sendCancelation() async {
        do {
            _ = try await sendCancelationRequest()
            toastManager.show(Text("successfully_sent_cancelation_request"), type: ToastType.success)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage ?? "unknown_error_message"), type: ToastType.error)
        }
    }
    
    private func cancelAppointment() async {
        do {
            _ = try await cancelAppointmentRequest()
            toastManager.show(Text("successfully_canceled_appointment"), type: ToastType.success)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage ?? "unknown_error_message"), type: ToastType.error)
        }
    }
    
    private func cancelAppointmentRequest() async throws -> Bool {
        let url = AppEnvironment.apiURL.appendingPathComponent("appointments/cancel/" + appointment.id.uuidString)
        
        let response: Bool = try await APIClient.shared.request(url)
        
        return response;
    }
    
    private func sendCancelationRequest() async throws -> StatusResponse {
        let url = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/cancelation/" + appointment.id.uuidString)
        
        let request = CancelationRequest(comment: cancelationComment)
        
        let response: StatusResponse = try await APIClient.shared.request(url, method: HTTPMethod.post, body: JSONEncoder().encode(request))
        
        return response;
    }
}

#Preview {
    AppointmentDetailsView(
        appointment: Appointment(
            id: UUID(),
            startTime: Date.now,
            endTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
            timeSlot: TimeSlot(
                id: UUID(),
                name: "Timeslot",
                description: "06:00 - 07:00"
            ),
            status: AppointmentStatus(
                id: UUID(),
                name: "approved",
                description: "approved_status"
            ),
            clients: [
                Client(
                    id: UUID(),
                    firstName: "Miki",
                    lastName: "Mikic",
                    email: "miki.mikic@mail.com",
                    phone: "+385911234567",
                    credits: 12,
                    bodyMeasurements: []
                )
            ]
        )
    )
    .environmentObject(AuthManager())
    .environmentObject(ToastManager())
}
