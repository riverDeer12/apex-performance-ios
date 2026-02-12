import SwiftUI

struct AppointmentsView: View {
    @State var appointments: [Appointment] = []
    @State private var isInitialLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    @State private var showCreateAppointmentForm = false
    
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
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("new_appointment")
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
            
            await MainActor.run {
                appointments = mapped
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                errorMessage = mapError(error)
            }
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
                        bodyMeasurements: []
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
                        bodyMeasurements: []
                    )
                ]
            ),
            Appointment(
                id: UUID(),
                startTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                endTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "08:00 - 09:00",
                    description: "08:00 - 09:00"
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
            ),
            Appointment(
                id: UUID(),
                startTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                endTime: Calendar.current.date(byAdding: .minute, value: 60, to: .now)!,
                timeSlot: TimeSlot(
                    id: UUID(),
                    name: "09:00 - 10:00",
                    description: "09:00 - 10:00"
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
        ]
    )
    .environmentObject(AuthManager())
    .environmentObject(ToastManager())
}

