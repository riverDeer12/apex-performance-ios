import SwiftUI

struct AppointmentsView: View {
    @State var appointments: [Appointment] = []
    @State var pendingAppointments: [Appointment] = []
    @State private var isInitialLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    @State private var processingAppointmentId: UUID?
    
    @State private var showCreateAppointmentForm = false
    
    @EnvironmentObject private var toastManager: ToastManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("appointments")
                            .font(.title.bold())
                        Text("upcoming_past_sessions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Pending Appointments Section
                    if !pendingAppointments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("pending_approvals")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            
                            CardView {
                                VStack(spacing: 0) {
                                    ForEach(pendingAppointments) { appointment in
                                        pendingAppointmentRow(appointment)
                                        
                                        if appointment.id != pendingAppointments.last?.id {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Approved Appointments Section Header
                    if !pendingAppointments.isEmpty {
                        Text("approved_appointments")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    
                    // Content card
                    CardView {
                        if appointments.isEmpty, !isInitialLoading {
                            Text("no_appointments")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(appointments) { appointment in
                                    NavigationLink {
                                        AppointmentDetailsView(appointment: appointment)
                                    } label: {
                                        appointmentRow(appointment)
                                    }
                                    .buttonStyle(.plain)
                                    .opacity(appointment.isActive ? 1 : 0.80)
                                    
                                    if appointment.id != appointments.last?.id {
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
            .overlay {
                if isInitialLoading && appointments.isEmpty {
                    ProgressView()
                }
            }
            .refreshable {
                await loadData(showInitialSpinner: false)
            }
            .task {
                await loadData(showInitialSpinner: true)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateAppointmentForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.apexMainColor)
                        
                    }
                    .accessibilityLabel("new_appointment")
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(isPresented: $showCreateAppointmentForm) {
                CreateAppointmentView()
            }
        }
    }
    
    private func appointmentRow(_ appointment: Appointment) -> some View {
        SettingsRowView(
            icon: appointment.isActive ? "calendar" : "checkmark.diamond",
            iconTint: appointment.isActive ? Color.apexMainColor : .green,
            title: Text(DateFormatter.dateWithDots.string(from: appointment.startTime)),
            subtitle: Text(appointment.timeSlot.description ?? "unknown_value"),
            showChevron: true
        )
        .contentShape(Rectangle())
    }
    
    private func pendingAppointmentRow(_ appointment: Appointment) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(Color.orange)
                        .font(.system(size: 18))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateFormatter.dateWithDots.string(from: appointment.startTime))
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(appointment.timeSlot.description ?? "unknown_value")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !appointment.clients.isEmpty {
                        Text(appointment.clients.map { $0.fullName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    Task { await approveAppointment(appointment) }
                } label: {
                    HStack {
                        if processingAppointmentId == appointment.id {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.green)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text("approve")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(processingAppointmentId == appointment.id)
                
                Button {
                    Task { await declineAppointment(appointment) }
                } label: {
                    HStack {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text("reject")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(processingAppointmentId == appointment.id)
            }
            .padding(.bottom, 8)
        }
    }
    
    private func loadData(showInitialSpinner: Bool) async {
        if showInitialSpinner {
            await MainActor.run { isInitialLoading = true }
        }
        defer {
            if showInitialSpinner {
                Task { @MainActor in isInitialLoading = false }
            }
        }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointments")
            let response: AppointmentsStatus = try await APIClient.shared.request(url)
                        
            let mapped = response.approvedAppointments.map {
                Appointment(
                    id: $0.id,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    timeSlot: $0.timeSlot,
                    status: $0.status,
                    clients: $0.clients
                )
            }
            
            let mappedPending = response.pendingAppointments.map {
                Appointment(
                    id: $0.id,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    timeSlot: $0.timeSlot,
                    status: $0.status,
                    clients: $0.clients
                )
            }
            
            await MainActor.run {
                appointments = mapped
                pendingAppointments = mappedPending
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                errorMessage = mapError(error)
            }
        }
    }
    
    private func approveAppointment(_ appointment: Appointment) async {
        processingAppointmentId = appointment.id
        defer { processingAppointmentId = nil }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointments/approve/\(appointment.id.uuidString)")
            let _: StatusResponse = try await APIClient.shared.request(url)
            
            toastManager.show("appointment_approved_successfully", type: .success)
            
            // Reload data to refresh the lists
            await loadData(showInitialSpinner: false)
        } catch {
            let errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage), type: .error)
        }
    }
    
    private func declineAppointment(_ appointment: Appointment) async {
        processingAppointmentId = appointment.id
        defer { processingAppointmentId = nil }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointments/decline/\(appointment.id.uuidString)")
            let _: StatusResponse = try await APIClient.shared.request(url)
            
            toastManager.show("appointment_declined_successfully", type: .success)
            
            // Reload data to refresh the lists
            await loadData(showInitialSpinner: false)
        } catch {
            let errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage), type: .error)
        }
    }
}

#Preview {
    AppointmentsView(
        appointments: [
            Appointment(
                id: UUID(),
                startTime: Date.now,
                endTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "06:00 - 07:00",
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
                        bodyMeasurements: [],
                        lastCreditsIncrease: .now
                    )
                ]
            ),
            Appointment(
                id: UUID(),
                startTime: Date.now,
                endTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "07:00 - 08:00",
                    description: "07:00 - 08:00"
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
                        bodyMeasurements: [],
                        lastCreditsIncrease: .now
                    )
                ]
            )
        ],
        pendingAppointments: [
            Appointment(
                id: UUID(),
                startTime: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
                endTime: Calendar.current.date(byAdding: .day, value: 1, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "10:00 - 11:00",
                    description: "10:00 - 11:00"
                ),
                status: AppointmentStatus(
                    id: UUID(),
                    name: "pending",
                    description: "pending_status"
                ),
                clients: [
                    Client(
                        id: UUID(),
                        firstName: "Ana",
                        lastName: "Anic",
                        email: "ana.anic@mail.com",
                        phone: "+385911234567",
                        credits: 5,
                        bodyMeasurements: [],
                        lastCreditsIncrease: .now
                    )
                ]
            ),
            Appointment(
                id: UUID(),
                startTime: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
                endTime: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "14:00 - 15:00",
                    description: "14:00 - 15:00"
                ),
                status: AppointmentStatus(
                    id: UUID(),
                    name: "pending",
                    description: "pending_status"
                ),
                clients: [
                    Client(
                        id: UUID(),
                        firstName: "Pero",
                        lastName: "Peric",
                        email: "pero.peric@mail.com",
                        phone: "+385911234567",
                        credits: 8,
                        bodyMeasurements: [],
                        lastCreditsIncrease: .now
                    )
                ]
            )
        ]
    )
    .environmentObject(AuthManager())
    .environmentObject(ToastManager())
}

