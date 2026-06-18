import SwiftUI

extension ISO8601DateFormatter {
    static let shared = ISO8601DateFormatter()
}

struct CreateAppointmentView: View {
    
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss  // Environment dismiss to close view
    
    @State private var errorMessage: String? = nil
    
    // Form values
    @State var startTime: Date = .now
    @State var endTime: Date = .now
    @State var selectedDay: Date = .now
    @State var selectedTimeSlot: UUID? = nil
    @State var selectedAppointmentType: UUID? = nil
    @State var selectedClients: [UUID] = []
    @State var selectedCoachId: UUID? = nil
    @State var selectedClientId: UUID? = nil
    @State var selectedCoaches: [UUID] = []
    
    // Data
    @State var timeSlots: [TimeSlot] = []
    @State var clients: [Client] = []
    @State var coaches: [Coach] = []
    @State var appointmentTypes: [CatalogData] = []
    
    // Loading flags
    @State private var isSaving: Bool = false
    @State private var isLoadingTimeSlots: Bool = false
    @State private var isLoadingAppointmentTypes: Bool = false
    @State private var isLoadingClients: Bool = false
    @State private var isLoadingCoaches: Bool = false
    
    var body: some View {
        ZStack {
            Form {
                DatePicker(
                    "select_day",
                    selection: $selectedDay,
                    in: getStartDate()...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .onChange(of: selectedDay) { _, newValue in
                    Task {
                        await loadTimeSlots(for: newValue)
                    }
                }
                
                if !authManager.hasRole(role: "Coach"){
                    Section {
                        if isLoadingCoaches {
                            ProgressView("loading_coaches")
                        }
                        
                        Picker("select_coaches", selection: $selectedCoachId) {
                            Text("select_value").tag(nil as UUID?)
                            
                            ForEach(coaches) { coach in
                                Text(coach.fullName).tag(coach.id as UUID?)
                            }
                        }
                        .disabled(isLoadingCoaches || coaches.isEmpty)
                        .onChange(of: selectedCoachId) { _, newValue in
                            selectedCoaches = newValue.map { [$0] } ?? []
                            Task { await loadTimeSlots(for: selectedDay) }
                        }
                    }
                }

                Section{
                    if isLoadingTimeSlots {
                        ProgressView("loading_time_slots")
                    }
                    
                    Picker("select_time_slot", selection: $selectedTimeSlot) {
                        Text("select_value").tag(nil as UUID?)
                        ForEach(timeSlots, id: \.self.id) { timeSlot in
                            Text(timeSlot.name ?? "unknown_value")
                                .tag(Optional(timeSlot.id))
                        }
                    }
                    .disabled(isLoadingTimeSlots || timeSlots.isEmpty)
                    .onChange(of: timeSlots) { _, timeSlots in
                        if timeSlots.count == 1 {
                            selectedTimeSlot = timeSlots.first?.id
                        } else if timeSlots.isEmpty {
                            selectedTimeSlot = nil
                        }
                    }
                }
                
                Section{
                    if isLoadingAppointmentTypes {
                        ProgressView("loading_appointment_types")
                    }
                    
                    Picker("select_appointment_type", selection: $selectedAppointmentType) {
                        Text("select_value").tag(nil as UUID?)
                        ForEach(appointmentTypes, id: \.self.id) { appointmentType in
                            Text(LocalizedStringKey(appointmentType.description.lowercased()))
                                .tag(Optional(appointmentType.id))
                        }
                    }
                    .disabled(isLoadingAppointmentTypes)
                }
                
                if(!authManager.hasRole(role: "Client")){
                    Section("select_clients") {
                        if isLoadingClients {
                            ProgressView("loading_clients")
                        }
                        
                        ForEach(clients) { client in
                            Toggle(client.fullName, isOn: Binding(
                                get: { selectedClients.contains(client.id) },
                                set: { isOn in
                                    if isOn { selectedClients.append(client.id) }
                                    else { selectedClients.removeAll { $0 == client.id } }
                                }
                            ))
                        }
                    }
                    .disabled(isLoadingClients || clients.isEmpty)
                }
            }
            if isSaving {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.3)
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .navigationTitle("new_appointment")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await createAppointment() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: isSelectedTimeSlotTaken ? "person.line.dotted.person" : "checkmark")
                            .foregroundStyle(Color.apexMainColor)
                        
                    }
                }
                .disabled(!canCreateAppointment)
                .buttonStyle(.plain)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadInitialData()
        }
    }
    
    @MainActor
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            
            if authManager.hasRole(role: "Coach"){
                group.addTask {
                    await setCurrentCoach()
                }
            } else {
                group.addTask { await loadCoaches() }
            }
            
            if authManager.hasRole(role: "Client"){
                group.addTask {
                    await setCurrentClient()
                }
            } else {
                group.addTask { await loadClients() }
            }
            
            
            group.addTask { await loadAppointmentTypes() }
        }
    }
    
    private func loadTimeSlots(for day: Date) async {
        isLoadingTimeSlots = true
        defer { isLoadingTimeSlots = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("time-slots/available")
            
            let dayString = DateManager.apiDateFormatter.string(from: day)
            
            let request = GetTimeSlotsRequest(coaches: selectedCoaches, day: dayString)
            
        
            let response: [TimeSlot] = try await APIClient.shared.request(url, method: HTTPMethod.post, body: JSONEncoder().encode(request))
                        
            timeSlots = response.map {
                TimeSlot(
                    id: $0.id,
                    name: $0.name,
                    day: $0.day,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    isTaken: $0.isTaken,
                    appointmentId: $0.appointmentId
                )
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    @MainActor
    private func setCurrentCoach() async {
        isLoadingCoaches = true
        defer { isLoadingCoaches = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("coaches/current-coach")
            let response: Coach = try await APIClient.shared.request(url)
            
            selectedCoachId = response.id
            selectedCoaches = [response.id]
            
            coaches = [response]
            
            await loadTimeSlots(for: selectedDay)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    @MainActor
    private func setCurrentClient() async {
        isLoadingClients = true
        defer { isLoadingClients = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("clients/current-client")
            let response: Client = try await APIClient.shared.request(url)
            
            selectedClientId = response.id
            selectedClients = [response.id]
            
            clients = [response]
            
            await loadTimeSlots(for: selectedDay)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    private func loadCoaches() async {
        isLoadingCoaches = true
        defer { isLoadingCoaches = false }
        
        do {
            
            let urlPrefix = authManager.hasRole(role: "Client") ? "client" : "all"
            
            let url = AppEnvironment.apiURL.appendingPathComponent("coaches/" + urlPrefix)
            
            let response: [Coach] = try await APIClient.shared.request(url)
            
            coaches = response.map {
                Coach(
                    id: $0.id,
                    firstName: $0.firstName,
                    lastName: $0.lastName,
                    email: $0.email,
                    phone: $0.phone
                )
            }
            if selectedCoachId == nil, let firstCoach = coaches.first {
                selectedCoachId = firstCoach.id
                selectedCoaches = [firstCoach.id]
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    private func loadClients() async {
        isLoadingClients = true
        defer { isLoadingClients = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("clients")
            let response: [Client] = try await APIClient.shared.request(url)
            
            clients = response.map {
                Client(
                    id: $0.id,
                    firstName: $0.firstName,
                    lastName: $0.lastName,
                    email: $0.email,
                    phone: $0.phone,
                    credits: $0.credits,
                    bodyMeasurements: $0.bodyMeasurements,
                    lastCreditsIncrease: $0.lastCreditsIncrease
                )
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    private func loadAppointmentTypes() async {
        isLoadingAppointmentTypes = true
        defer { isLoadingAppointmentTypes = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointment-types")
            let response: [CatalogData] = try await APIClient.shared.request(url)
            
            appointmentTypes = response.map {
                CatalogData(
                    id: $0.id,
                    name: $0.name,
                    description: $0.description
                )
            }
            if selectedAppointmentType == nil, let firstType = appointmentTypes.first {
                selectedAppointmentType = firstType.id
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    private func getStartDate() -> Date {
        let today = Date.now
        
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
        )
        
        return authManager.hasRole(role: "Client") ? tomorrow : today
    }
    
    private var canCreateAppointment: Bool {
        selectedTimeSlot != nil &&
        !selectedClients.isEmpty &&
        !selectedCoaches.isEmpty &&
        !isSaving
    }
    
    private var isSelectedTimeSlotTaken: Bool {
        guard let selectedTimeSlot = selectedTimeSlot,
              let timeSlot = timeSlots.first(where: { $0.id == selectedTimeSlot }) else {
            return false
        }
        return timeSlot.isTaken ?? false
    }
    
    private func createAppointment() async {
        do {
            if isSelectedTimeSlotTaken {
                _ = try await joinExistingAppointment()
                toastManager.show(LocalizedStringKey("successfully_joined_appointment"), type: ToastType.success)
            } else {
                _ = try await sendNewAppointmentToApi()
                toastManager.show(LocalizedStringKey("successfully_created_appointment"), type: ToastType.success)
            }
            dismiss()
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
    
    private func sendNewAppointmentToApi() async throws -> StatusResponse {
        guard let selectedTimeSlot = selectedTimeSlot,
              let timeSlot = timeSlots.first(where: { $0.id == selectedTimeSlot }) else {
            throw NSError(domain: "CreateAppointmentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or missing time slot"])
        }
        
        let calendar = Calendar.current
        let selectedDayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDay)
        
        func dateFrom(dayComponents: DateComponents, timeString: String) -> Date? {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            guard let timeDate = timeFormatter.date(from: timeString) else {
                return nil
            }
            
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeDate)
            
            var combinedComponents = DateComponents()
            combinedComponents.year = dayComponents.year
            combinedComponents.month = dayComponents.month
            combinedComponents.day = dayComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute
            combinedComponents.second = timeComponents.second
            
            return calendar.date(from: combinedComponents)
        }
        
        guard let startTimeDate = dateFrom(dayComponents: selectedDayComponents, timeString: timeSlot.startTime ?? ""),
              let endTimeDate = dateFrom(dayComponents: selectedDayComponents, timeString: timeSlot.endTime ?? "") else {
            throw NSError(domain: "CreateAppointmentView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse time slot start or end time"])
        }
        
        let url = AppEnvironment.apiURL.appendingPathComponent("appointments")
        
        let isoFormatter = ISO8601DateFormatter()
        
        let request = CreateAppointmentRequest(
            type: selectedAppointmentType!,
            timeSlot: selectedTimeSlot,
            clients: selectedClients,
            coaches: selectedCoaches,
            startTime: isoFormatter.string(from: startTimeDate),
            endTime: isoFormatter.string(from: endTimeDate)
        )
        
        let response: StatusResponse = try await APIClient.shared.request(url, method: HTTPMethod.post, body: JSONEncoder().encode(request))
                
        return response;
    }
    
    private func joinExistingAppointment() async throws -> StatusResponse {
        guard let selectedTimeSlot = selectedTimeSlot,
              let timeSlot = timeSlots.first(where: { $0.id == selectedTimeSlot }),
              let appointmentId = timeSlot.appointmentId else {
            throw NSError(domain: "CreateAppointmentView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid or missing appointment ID"])
        }
        
        let url = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/join/\(appointmentId)")
        
        let response: StatusResponse = try await APIClient.shared.request(url, method: HTTPMethod.get, body: nil)
        
        return response
    }
}

