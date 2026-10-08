//
//  ClientDetails.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 24.12.2025..
//

import SwiftUI

struct ClientDetailsView: View {
    
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss
    
    let client: Client
    
    @State private var form: Client
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var lastPayment: Date = Date()
    @State private var daysUntilExpiration: Int = 0
    @State private var showCreateBodyMeasurementSheet = false
    @State private var functionalMovementScreens: [FunctionalMovementScreen] = []
    @State private var isLoadingFunctionalMovementScreens = false
    @State private var showCreateFunctionalMovementScreenSheet = false
    @State private var trainings: [Training] = []
    @State private var showCreateTrainingSheet = false
    @State private var goal = ClientGoal()
    @State private var showGoalSheet = false
    @State private var monthlyReviews: [MonthlyReview] = []
    // Review opened for editing; a new one when the sheet is shown without it.
    @State private var editedReview: MonthlyReview?
    @State private var showReviewSheet = false
    
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
                            
                            HStack(spacing: 6) {
                                Text(form.email ?? "no_email")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if let email = form.email {
                                    Button {
                                        UIPasteboard.general.string = email
                                        toastManager.show("email_copied", type: .success)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
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
                            HStack(spacing: 8) {
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
                                
                                if let email = form.email, !email.isEmpty {
                                    Button {
                                        UIPasteboard.general.string = email
                                        toastManager.show("email_copied", type: .success)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        Divider()
                        editableRow(title: "mobile_phone") {
                            HStack(spacing: 8) {
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
                                
                                if let phone = form.phone, !phone.isEmpty {
                                    Button {
                                        UIPasteboard.general.string = phone
                                        toastManager.show("phone_copied", type: .success)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                CardView(title: "plan") {
                    editableRow(title: "plan") {
                        Picker("plan", selection: Binding(
                            get: { ClientPlan(rawValue: form.plan ?? "") ?? .privateCoaching },
                            set: { form.plan = $0.rawValue }
                        )) {
                            ForEach(ClientPlan.allCases) { plan in
                                Text(plan.title).tag(plan)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.apexMainColor)
                    }
                }
                .padding(.horizontal, 20)
                
                let outOfCredits = (form.credits ?? 0) <= 0
                
                CardView(title: "credits") {
                    VStack(spacing: 0) {
                        editableRow(title: "appointments_left") {
                            NumberWheelField(
                                value: $form.credits.asDecimal,
                                range: 0...200,
                                title: "appointments_left"
                            )
                            .font(outOfCredits ? .body.weight(.bold) : .body)
                        }
                        
                        Divider().padding(.leading, 0)
                        editableRow(title: "Last Payment") {
                            Text(DateFormatter.dateAndTimeWithDots.string(from: form.lastCreditsIncrease ?? .now))
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                if let bodyMeasurements = form.bodyMeasurements, !bodyMeasurements.isEmpty {
                    WeightProgressChartView(measurements: bodyMeasurements)
                        .padding(.horizontal, 20)
                }
                
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("body_measurements")
                                .font(.headline)
                                .padding(.top, 2)
                            
                            Spacer()
                            
                            Button {
                                showCreateBodyMeasurementSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(Color.apexMainColor)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                                            .fill(Color(.systemGray6))
                                    )
                            }
                            .buttonStyle(.borderless)
                        }
                        
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
                                        BodyMeasurementDetailsView(bodyMeasurement: bodyMeasurement) { id in
                                            form.bodyMeasurements?.removeAll { $0.id == id }
                                        }
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
                }
                .padding(.horizontal, 20)
                .sheet(isPresented: $showCreateBodyMeasurementSheet) {
                    CreateBodyMeasurementView(client: client) {
                        showCreateBodyMeasurementSheet = false
                    }
                }
                
                functionalMovementScreensCard
                    .padding(.horizontal, 20)
                
                goalCard
                    .padding(.horizontal, 20)
                
                monthlyReviewsCard
                    .padding(.horizontal, 20)
                
                trainingsCard
                    .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationTitle(client.fullName)
        .navigationBarTitleDisplayMode(.inline)
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
                    Task { await save() }
                } label: {
                    ZStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .disabled(isSaving)
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await loadFunctionalMovementScreens()
        }
        .task {
            await loadTrainings()
        }
        .task {
            await loadGoalAndReviews()
        }
        .sheet(isPresented: $showGoalSheet) {
            ClientGoalFormView(clientId: client.id, goal: goal) { saved in
                goal = saved
            }
        }
        .sheet(isPresented: $showReviewSheet, onDismiss: { editedReview = nil }) {
            MonthlyReviewFormView(clientId: client.id, reviews: monthlyReviews, review: editedReview) {
                Task { await loadGoalAndReviews() }
            }
        }
        .sheet(isPresented: $showCreateTrainingSheet) {
            TrainingFormView(clientId: client.id, history: trainings) { saved in
                upsertTraining(saved)
            }
        }
        .sheet(isPresented: $showCreateFunctionalMovementScreenSheet) {
            NavigationStack {
                FunctionalMovementScreenView(clientId: client.id) {
                    Task { await loadFunctionalMovementScreens() }
                }
            }
        }
    }
    
    private var goalCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("goal_and_plan")
                        .font(.headline)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    Button {
                        showGoalSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundStyle(Color.apexMainColor)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("edit_goal_and_plan"))
                }
                
                if goal.isEmpty {
                    Text("no_goal_and_plan")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    ClientGoalContentView(goal: goal)
                }
            }
        }
    }
    
    private var monthlyReviewsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("monthly_reviews")
                        .font(.headline)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    Button {
                        editedReview = nil
                        showReviewSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(Color.apexMainColor)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("new_monthly_review"))
                }
                
                if monthlyReviews.isEmpty {
                    Text("no_monthly_reviews")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(monthlyReviews) { review in
                            Button {
                                editedReview = review
                                showReviewSheet = true
                            } label: {
                                SettingsRowView(
                                    icon: "doc.text",
                                    iconTint: Color.apexAccent,
                                    title: Text(review.monthDate, format: .dateTime.month(.wide).year()),
                                    subtitle: Text(verbatim: review.content),
                                    showChevron: true
                                )
                                .lineLimit(2)
                            }
                            .buttonStyle(.plain)
                            
                            if review.id != monthlyReviews.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadGoalAndReviews() async {
        do {
            goal = try await ClientGoal.load(clientId: client.id)
            monthlyReviews = try await MonthlyReview.load(clientId: client.id)
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
    
    private var trainingsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("trainings")
                        .font(.headline)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    Button {
                        showCreateTrainingSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(Color.apexMainColor)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("new_training"))
                }
                
                if trainings.isEmpty {
                    Text("no_trainings")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    if trainings.contains(where: \.isCompleted) {
                        NavigationLink {
                            ClientTrainingProgressView(clientName: client.fullName, trainings: trainings)
                        } label: {
                            SettingsRowView(
                                icon: "chart.line.uptrend.xyaxis",
                                iconTint: Color.apexAccent,
                                title: Text("training_progress_title"),
                                subtitle: nil,
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Divider().padding(.leading, 52)
                    }
                    
                    TrainingRowsView(
                        trainings: trainings,
                        onSaved: { saved in upsertTraining(saved) },
                        onDeleted: { id in trainings.removeAll { $0.id == id } }
                    )
                }
            }
        }
    }
    
    private var functionalMovementScreensCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("fms")
                        .font(.headline)
                        .padding(.top, 2)
                    
                    Spacer()
                    
                    Button {
                        showCreateFunctionalMovementScreenSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(Color.apexMainColor)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 50, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.borderless)
                }
                
                if isLoadingFunctionalMovementScreens && functionalMovementScreens.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else if functionalMovementScreens.isEmpty {
                    Text("no_fms")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(functionalMovementScreens) { screen in
                            NavigationLink {
                                FunctionalMovementScreenView(clientId: client.id, screen: screen) {
                                    Task { await loadFunctionalMovementScreens() }
                                }
                            } label: {
                                SettingsRowView(
                                    icon: "figure.strengthtraining.functional",
                                    iconTint: .blue,
                                    title: Text(DateFormatter.dateAndTimeWithDots.string(from: screen.createdAt)),
                                    subtitle: nil,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                            if screen.id != functionalMovementScreens.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // API returns the trainings of all the coach's clients,
    // so only this client's are kept, newest first.
    @MainActor
    private func loadTrainings() async {
        do {
            trainings = try await Training.loadAll()
                .filter { $0.client.id == client.id }
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
    
    private func upsertTraining(_ training: Training) {
        trainings.removeAll { $0.id == training.id }
        trainings.append(training)
        trainings.sort { $0.date > $1.date }
    }
    
    // API returns all FMS the logged user can see,
    // so only this client's are kept, newest first.
    @MainActor
    private func loadFunctionalMovementScreens() async {
        isLoadingFunctionalMovementScreens = true
        defer { isLoadingFunctionalMovementScreens = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("functional-movement-screens")
            let screens: [FunctionalMovementScreen] = try await APIClient.shared.request(url)
            functionalMovementScreens = screens
                .filter { $0.client.id == client.id }
                .sorted { $0.createdAt > $1.createdAt }
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
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
            toastManager.show("successfully_updated_user", type: ToastType.success)
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
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

