import SwiftUI

struct AppointmentsView: View {
    @State var appointments: [Appointment] = []
    @State var pendingAppointments: [Appointment] = []
    @State private var isInitialLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    @State private var processingAppointmentId: UUID?
    // Pending cancelation and join requests, shown to staff above the calendar.
    @State private var appointmentRequests: [AppointmentRequest] = []
    @State private var processingRequestId: UUID?
    
    @State private var showCreateAppointmentForm = false
    @State private var showSentRequests = false
    @State private var isGeneratingRecurring = false
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header
                    ApexScreenHeader(title: "appointments", subtitle: "upcoming_past_sessions")
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    if isClient {
                        Button("book_appointment") {
                            showCreateAppointmentForm = true
                        }
                        .buttonStyle(ApexPrimaryButtonStyle())
                        .padding(.horizontal, 20)
                    }
                    
                    // Pending Appointments Section
                    if !pendingAppointments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("pending_approvals")
                                .apexLabel()
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
                    
                    requestsSection(title: "cancelation_requests", requests: cancelationRequests)
                    
                    requestsSection(title: "join_requests", requests: joinRequests)
                    
                    // Approved Appointments Section Header
                    if !pendingAppointments.isEmpty || !cancelationRequests.isEmpty || !joinRequests.isEmpty {
                        Text("approved_appointments")
                            .apexLabel()
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    // Calendar
                    CardView {
                        CalendarMonthView(
                            selectedDate: $selectedDate,
                            approvedDates: approvedDates,
                            pendingDates: pendingDatesByDay
                        )
                    }
                    .padding(.horizontal, 20)

                    // Selected day appointments
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DateFormatter.dateWithDots.string(from: selectedDate))
                            .apexLabel()
                            .padding(.horizontal, 20)

                        CardView {
                            if appointmentsForSelectedDate.isEmpty, !isInitialLoading {
                                Text("no_appointments_for_selected_day")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(appointmentsForSelectedDate) { appointment in
                                        NavigationLink {
                                            AppointmentDetailsView(appointment: appointment)
                                        } label: {
                                            appointmentRow(appointment)
                                        }
                                        .buttonStyle(.plain)
                                        .opacity(appointment.isActive ? 1 : 0.80)

                                        if appointment.id != appointmentsForSelectedDate.last?.id {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.apexBackground)
            .overlay {
                if isInitialLoading && appointments.isEmpty {
                    ProgressView()
                }
            }
            .overlay {
                if isGeneratingRecurring {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(Color.apexMainColor)
                            
                            Text("generating_recurring_appointments")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 40)
                    }
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    
                    if isClient {
                        // Requests the client sent, with their status.
                        Button {
                            showSentRequests = true
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.apexMainColor)
                        }
                        .accessibilityLabel("appointment_requests")
                        .accessibilityIdentifier("requests-button")
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                    
                    if(authManager.hasRole(role: "Coach")){
                        Button {
                            Task { await generateRecurringAppointments() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color.apexMainColor)
                        }
                        .accessibilityLabel("generate_recurring_appointments")
                        .buttonStyle(.plain)
                        .disabled(isGeneratingRecurring)
                        // Same inset from the left edge as + has from the right.
                        .padding(.horizontal, 8)
                    }
                    
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
            .sheet(isPresented: $showSentRequests) {
                AppointmentRequestsView()
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var isClient: Bool {
        authManager.hasRole(role: "Client")
    }
    
    private var canManageRequests: Bool {
        !isClient
    }
    
    private var cancelationRequests: [AppointmentRequest] {
        appointmentRequests.filter { $0.type.name.lowercased() == "cancelationrequest" }
    }
    
    private var joinRequests: [AppointmentRequest] {
        appointmentRequests.filter { $0.type.name.lowercased() == "joinrequest" }
    }
    
    @ViewBuilder
    private func requestsSection(title: LocalizedStringKey, requests: [AppointmentRequest]) -> some View {
        if !requests.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .apexLabel()
                    .padding(.horizontal, 20)
                
                CardView {
                    VStack(spacing: 0) {
                        ForEach(requests) { request in
                            appointmentRequestRow(request)
                            
                            if request.id != requests.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func appointmentRequestRow(_ request: AppointmentRequest) -> some View {
        let isCancelation = request.type.name.lowercased() == "cancelationrequest"
        let tint: Color = isCancelation ? .red : .blue
        let isProcessing = processingRequestId == request.id
        
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isCancelation ? "calendar.badge.minus" : "person.badge.plus")
                        .foregroundStyle(tint)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.sender.fullName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(DateFormatter.dateWithDots.string(from: request.appointment.startTime)
                         + " · " + (request.appointment.timeSlot.description ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !request.comment.isEmpty {
                        Text(request.comment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            
            HStack(spacing: 12) {
                Button {
                    Task { await processRequest(request, action: "approve") }
                } label: {
                    HStack {
                        if isProcessing {
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
                .disabled(isProcessing)
                
                Button {
                    Task { await processRequest(request, action: "decline") }
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
                .disabled(isProcessing)
            }
            .padding(.bottom, 8)
        }
    }
    
    // action is "approve" or "decline", same endpoints as the requests tab.
    private func processRequest(_ request: AppointmentRequest, action: String) async {
        processingRequestId = request.id
        defer { processingRequestId = nil }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/\(action)/\(request.id.uuidString)")
            let _: StatusResponse = try await APIClient.shared.request(url)
            
            toastManager.show(
                action == "approve" ? "request_approved_successfully" : "request_rejected_successfully",
                type: .success
            )
            
            // Approving changes appointments too, so reload everything.
            await loadData(showInitialSpinner: false)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private var approvedDates: Set<Date> {
        Set(appointments.map { Calendar.current.startOfDay(for: $0.startTime) })
    }

    private var pendingDatesByDay: Set<Date> {
        Set(pendingAppointments.map { Calendar.current.startOfDay(for: $0.startTime) })
    }

    private var appointmentsForSelectedDate: [Appointment] {
        appointments
            .filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
            .sorted { $0.startTime < $1.startTime }
    }

    private func appointmentRow(_ appointment: Appointment) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill((appointment.isActive ? Color.apexMainColor : Color.green).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: appointment.isActive ? "calendar" : "checkmark.diamond")
                    .foregroundStyle(appointment.isActive ? Color.apexMainColor : .green)
                    .font(.system(size: 18))
            }
            
            // Client name(s) on the left
            VStack(alignment: .leading, spacing: 2) {
                if !appointment.clients.isEmpty {
                    // Display first client's name split into two lines
                    let client = appointment.clients[0]
                    Text(client.firstName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(client.lastName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("no_client")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Date and Time on the right
            VStack(alignment: .trailing, spacing: 4) {
                Text(appointment.timeSlot.description ?? "unknown_value")
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                
                Text(DateFormatter.dateWithDots.string(from: appointment.startTime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
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
            
            // Requests are loaded separately so a failure there
            // doesn't hide the appointments.
            let requests: [AppointmentRequest]
            if canManageRequests {
                let requestsURL = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/pending")
                let fetched: [AppointmentRequest]? = try? await APIClient.shared.request(requestsURL)
                requests = fetched ?? appointmentRequests
            } else {
                requests = []
            }
            
            await MainActor.run {
                appointments = mapped
                pendingAppointments = mappedPending
                appointmentRequests = requests.sorted { $0.appointment.startTime < $1.appointment.startTime }
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
    
    private func generateRecurringAppointments() async {
        isGeneratingRecurring = true
        defer { isGeneratingRecurring = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("recurring-appointments/generate-next-week")
            let _: Int = try await APIClient.shared.request(url)
            
            toastManager.show("recurring_appointments_generated_successfully", type: .success)

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

