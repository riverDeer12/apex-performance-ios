import SwiftUI

struct AppointmentRequestDetailsView: View {
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss
    
    let request: AppointmentRequest
    
    @State private var showApproveDialog = false
    @State private var showRejectDialog = false
    @State private var isProcessing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("request_details")
                        .font(.title2.bold())
                    
                    Text("review_and_take_action")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Request info card
                CardView(title: "request_information") {
                    VStack(spacing: 12) {
                        HStack {
                            Text("sender")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(request.sender.fullName)
                                .font(.subheadline.weight(.medium))
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("request_type")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(request.type.name)
                                .font(.subheadline.weight(.medium))
                        }
                        
                        if !request.comment.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("comment")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(request.comment)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Related appointment card
                CardView(title: "related_appointment") {
                    NavigationLink {
                        AppointmentDetailsView(appointment: request.appointment)
                    } label: {
                        SettingsRowView(
                            icon: "calendar",
                            iconTint: Color.apexMainColor,
                            title: Text(DateFormatter.dateWithDots.string(from: request.appointment.startTime)),
                            subtitle: Text(request.appointment.timeSlot.description ?? "unknown_value"),
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                
                // Actions card
                CardView(title: "actions") {
                    VStack(spacing: 0) {
                        Button {
                            showApproveDialog = true
                        } label: {
                            SettingsRowView(
                                icon: "checkmark.circle",
                                iconTint: .green,
                                title: Text("approve_request"),
                                subtitle: Text("approve_request_info"),
                                showChevron: true,
                                titleColor: .green
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)
                        
                        Divider().padding(.leading, 52)
                        
                        Button(role: .destructive) {
                            showRejectDialog = true
                        } label: {
                            SettingsRowView(
                                icon: "xmark.circle",
                                iconTint: .red,
                                title: Text("reject_request"),
                                subtitle: Text("reject_request_info"),
                                showChevron: true,
                                titleColor: .red
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 12)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("approve_request_question", isPresented: $showApproveDialog) {
            Button("approve") {
                Task { await approveRequest() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("approve_request_confirmation")
        }
        .confirmationDialog("reject_request_question", isPresented: $showRejectDialog) {
            Button("reject", role: .destructive) {
                Task { await rejectRequest() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("reject_request_confirmation")
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
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func approveRequest() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await processRequest(action: "approve")
            toastManager.show("request_approved_successfully", type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        } catch {
            let errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage), type: .error)
        }
    }
    
    private func rejectRequest() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await processRequest(action: "reject")
            toastManager.show("request_rejected_successfully", type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        } catch {
            let errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage), type: .error)
        }
    }
    
    private func processRequest(action: String) async throws {
        let url = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/\(action)/\(request.id.uuidString)")
        let _: StatusResponse = try await APIClient.shared.request(url, method: .post)
    }
}

#Preview("Request Details") {
    NavigationStack {
        AppointmentRequestDetailsView(
            request: AppointmentRequest(
                id: UUID(),
                comment: "I have an urgent meeting and cannot attend this session. Please cancel my appointment.",
                sender: Client(
                    id: UUID(),
                    firstName: "Pero",
                    lastName: "Peric",
                    email: "pero.peric@example.com",
                    phone: nil,
                    credits: nil,
                    bodyMeasurements: nil,
                    lastCreditsIncrease: nil
                ),
                type: CatalogData(
                    id: UUID(),
                    name: "CancellationRequest",
                    description: "Request to cancel appointment"
                ),
                appointment: Appointment(
                    id: UUID(),
                    startTime: Date.now,
                    endTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now)!,
                    timeSlot: TimeSlot(
                        id: UUID(),
                        name: "Morning",
                        description: "08:00 - 09:00"
                    ),
                    status: AppointmentStatus(
                        id: UUID(),
                        name: "approved",
                        description: "Approved"
                    ),
                    clients: []
                )
            )
        )
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
    }
}
