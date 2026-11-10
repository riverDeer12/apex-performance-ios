//
//  ClientHomeView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's home: greeting, next training with booking, package,
/// goal and plan, and shortcuts to trainings, progress and workouts.
struct ClientHomeView: View {
    @Binding var selectedTab: AppTab
    // Set from outside (e.g. a body measurement notification) to open progress.
    @Binding var showsProgress: Bool

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager

    @State private var client: UserProfile?
    @State private var profile: Profile?
    @State private var approvedAppointments: [Appointment] = []
    @State private var pendingAppointments: [Appointment] = []
    @State private var isLoading = false
    @State private var showCreateAppointment = false
    @State private var goal: ClientGoal?
    @State private var showGoalSheet = false
    // The client's coach, shown with the next training when there is one.
    @State private var coachName: String?
    // Goal card lines cut at their line limit, for "Show more".
    @State private var truncatedGoalLines: Set<String> = []

    // Changed on every load, the Apple Health card reads the day again.
    @State private var healthRefresh = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    greeting

                    nextAppointmentCard

                    packageCard

                    if let goal, !goal.isEmpty {
                        goalCard(goal)
                    }

                    HealthDailyCard(refreshID: healthRefresh)

                    shortcuts
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color.apexBackground)
            .refreshable {
                await Task { await load() }.value
            }
            // Fresh data every time the screen is shown, not only after pulling
            // to refresh. Own task, so leaving the screen doesn't cancel it.
            .task {
                await Task { await load() }.value
            }
            .navigationBarTitleDisplayMode(.inline)
            .chatToolbarButton()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ApexTitleBar(subtitle: ClientPlan.title(for: client?.plan))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBellButton()
                }
            }
            .navigationDestination(isPresented: $showCreateAppointment) {
                CreateAppointmentView()
            }
            .navigationDestination(isPresented: $showsProgress) {
                ClientProgressView()
            }
            .sheet(isPresented: $showGoalSheet, onDismiss: markGoalSeen) {
                if let goal {
                    ClientGoalSheet(goal: goal)
                }
            }
        }
    }

    // MARK: - Sections

    private var greeting: some View {
        HStack(spacing: 12) {
            ProfilePictureView(profile: profile, size: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let firstName = client?.firstName, !firstName.isEmpty {
                    Text("hello_name \(firstName)")
                        .font(.system(size: 22, weight: .bold))
                }
                Text("ready_for_next_training")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var nextAppointmentCard: some View {
        ApexPictureBackground(systemImage: "figure.strengthtraining.traditional")
            .frame(height: 210)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            }
            // Time left until an approved training, e.g. "in 21 h".
            .overlay(alignment: .topLeading) {
                if let appointment = nextAppointment, !appointment.isPending,
                   let countdown = Self.countdown(to: appointment.startTime) {
                    Label {
                        Text(countdown)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.apexOnAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.apexAccent))
                    .padding(14)
                    .accessibilityIdentifier("next-training-countdown")
                }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let appointment = nextAppointment {
                            Text(appointment.isPending
                                 ? LocalizedStringKey("next_appointment_pending")
                                 : LocalizedStringKey("next_appointment"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))

                            Text(verbatim: Self.dateAndTime(appointment.startTime))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            nextAppointmentDetails(appointment)
                        } else if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("no_upcoming_appointments")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if canGetAppointments {
                        Button("book_appointment") {
                            showCreateAppointment = true
                        }
                        .buttonStyle(ApexCompactButtonStyle())
                        .accessibilityIdentifier("book-appointment-button")
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Duration and coach of the next training, e.g. "60 min · Luka Marić".
    @ViewBuilder
    private func nextAppointmentDetails(_ appointment: NextAppointment) -> some View {
        let minutes = Int(appointment.endTime.timeIntervalSince(appointment.startTime) / 60)
        let hasDuration = minutes > 0 && minutes < 24 * 60
        if hasDuration || coachName != nil {
            HStack(spacing: 12) {
                if hasDuration {
                    Label {
                        Text("duration_minutes \(minutes)")
                    } icon: {
                        Image(systemName: "timer")
                    }
                }
                if let coachName {
                    Label {
                        Text(verbatim: coachName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "person")
                    }
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
        }
    }

    /// "in 45 min", "in 21 h", "tomorrow" or "in 3 days", nil when it already started.
    static func countdown(to date: Date, now: Date = .now) -> LocalizedStringKey? {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 {
            return "countdown_minutes \(minutes)"
        }
        let hours = Int(seconds / 3600)
        if hours < 24 {
            return "countdown_hours \(hours)"
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return days <= 1 ? "countdown_tomorrow" : "countdown_days \(days)"
    }

    private var packageCard: some View {
        let package = PackageSummary(client: client, approvedAppointments: approvedAppointments)

        return NavigationLink {
            MyPackageView(
                client: client,
                approvedAppointments: approvedAppointments,
                pendingAppointments: pendingAppointments
            )
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("my_package")
                        .apexSectionTitle()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("package_done_of_total \(package.done) \(package.total)")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 8)
                    Text("package_remaining \(package.remaining)")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                ApexProgressBar(value: package.progress, height: 8)
            }
            .padding(16)
            .apexCardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("package-card")
    }

    private func goalCard(_ goal: ClientGoal) -> some View {
        NavigationLink {
            ClientGoalDetailView(goal: goal)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "scope")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.apexAccent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 8) {
                    Text("my_goal_and_plan")
                        .apexSectionTitle()
                        .padding(.bottom, 2)

                    // Whole sentences on a few lines; the rest in the details.
                    goalLine("goal", "goal_line \(goal.goal ?? "")", value: goal.goal, isPrimary: true)
                    goalLine("block", "current_block_line \(goal.currentBlock ?? "")", value: goal.currentBlock)
                    goalLine("focus", "focus_line \(goal.focus ?? "")", value: goal.focus)
                    Group {
                        if let date = goal.nextAssessmentDate {
                            Text("next_assessment_line \(DateFormatter.dateWithDots.string(from: date))")
                        } else if let text = goal.nextAssessment, !text.isEmpty {
                            Text("next_assessment_line \(text)")
                                .lineLimit(2)
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                    // Opens the details, as the whole card does.
                    if !truncatedGoalLines.isEmpty {
                        ShowMoreLabel()
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .apexCardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("goal-card")
    }

    @ViewBuilder
    private func goalLine(_ id: String, _ text: LocalizedStringKey, value: String?, isPrimary: Bool = false) -> some View {
        if let value, !value.isEmpty {
            TruncationAwareText(
                text: Text(text)
                    .font(.system(size: isPrimary ? 16 : 15, weight: isPrimary ? .semibold : .regular))
                    .foregroundStyle(isPrimary ? Color.primary : Color.secondary),
                lineLimit: 3,
                isTruncated: Binding(
                    get: { truncatedGoalLines.contains(id) },
                    set: { isTruncated in
                        if isTruncated {
                            truncatedGoalLines.insert(id)
                        } else {
                            truncatedGoalLines.remove(id)
                        }
                    }
                )
            )
        }
    }

    private var shortcuts: some View {
        let access = WorkoutLibraryAccess(plan: client?.plan)

        return VStack(spacing: 0) {
            Button {
                selectedTab = .trainings
            } label: {
                shortcutRow(title: "my_trainings", systemImage: "dumbbell")
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.apexBorder)

            Button {
                showsProgress = true
            } label: {
                shortcutRow(title: "progress", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-tile")

            // Workout library depends on the plan agreed with the coach.
            if access != .none {
                Divider().overlay(Color.apexBorder)

                NavigationLink {
                    WorkoutsView(
                        workoutFilter: access.allows,
                        title: access == .all ? "exercise_library" : "mobility_and_stretching",
                        subtitle: access == .all ? "exercise_library_subtitle" : "mobility_and_stretching_subtitle",
                        wrapsInNavigationStack: false
                    )
                } label: {
                    shortcutRow(
                        title: access == .all ? "exercise_library" : "mobility_and_stretching",
                        systemImage: access == .all ? "figure.strengthtraining.functional" : "figure.flexibility"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library-tile")
            }
        }
        .padding(.horizontal, 16)
        .apexCardBackground()
    }

    private func shortcutRow(title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.apexMainColor)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Goal shown after login

    private var seenGoalKey: String {
        "seenClientGoalUpdatedAt-\(authManager.username)"
    }

    /// Shows the goal and plan when the coach wrote or changed it
    /// since the client last saw it.
    private func showGoalIfChanged() {
        guard let goal, !goal.isEmpty, let updatedAt = goal.updatedAt else { return }
        let seen = UserDefaults.standard.double(forKey: seenGoalKey)
        if updatedAt.timeIntervalSince1970 > seen + 1 {
            showGoalSheet = true
        }
    }

    private func markGoalSeen() {
        guard let updatedAt = goal?.updatedAt else { return }
        UserDefaults.standard.set(updatedAt.timeIntervalSince1970, forKey: seenGoalKey)
    }

    // MARK: - Data

    private var canGetAppointments: Bool {
        authManager.hasPermission(permission: Permissions.canGetAppointments)
    }

    private struct NextAppointment {
        let startTime: Date
        let endTime: Date
        let isPending: Bool
    }

    /// Next approved appointment, or the next one waiting for approval.
    private var nextAppointment: NextAppointment? {
        let now = Date()
        if let approved = approvedAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: approved.startTime, endTime: approved.endTime, isPending: false)
        }
        if let pending = pendingAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: pending.startTime, endTime: pending.endTime, isPending: true)
        }
        return nil
    }

    // For example "8.10.2026. 18:00".
    static func dateAndTime(_ date: Date) -> String {
        "\(DateFormatter.dateWithDots.string(from: date)) \(date.formatted(date: .omitted, time: .shortened))"
    }

    @MainActor
    private func load() async {
        // The Health card reads the day again too.
        healthRefresh = UUID()
        isLoading = true
        defer { isLoading = false }

        // Loaded separately so one failing doesn't hide the other.
        async let clientResult: UserProfile? = loadClient()
        async let appointmentsResult: AppointmentsStatus? = loadAppointments()

        let (loadedClient, appointments) = await (clientResult, appointmentsResult)
        if let loadedClient {
            client = loadedClient
        }
        if let appointments {
            approvedAppointments = appointments.approvedAppointments
            pendingAppointments = appointments.pendingAppointments
        }

        // Picture, goal and plan are extras, home works without them.
        let profileURL = AppEnvironment.apiURL.appendingPathComponent("profile")
        if let loadedProfile: Profile = try? await APIClient.shared.request(profileURL) {
            profile = loadedProfile
        }
        if let loadedGoal = try? await ClientGoal.loadMine() {
            goal = loadedGoal
            showGoalIfChanged()
        }
        // Appointments don't name the coach: shown when the client has one coach.
        if canGetAppointments, coachName == nil,
           let coaches: [Coach] = try? await APIClient.shared.request(
               AppEnvironment.apiURL.appendingPathComponent("coaches/client")),
           coaches.count == 1 {
            let name = [coaches[0].firstName, coaches[0].lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            coachName = name.isEmpty ? nil : name
        }
    }

    @MainActor
    private func loadClient() async -> UserProfile? {
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("clients/current-client")
            return try await APIClient.shared.request(url)
        } catch let error where error.isCancellation {
            return nil
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
            return nil
        }
    }

    @MainActor
    private func loadAppointments() async -> AppointmentsStatus? {
        guard canGetAppointments else { return nil }
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("appointments")
            return try await APIClient.shared.request(url)
        } catch let error where error.isCancellation {
            return nil
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
            return nil
        }
    }
}

/// Centered "APEX" wordmark with a small subtitle, e.g. the client's plan.
struct ApexTitleBar: View {
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "APEX")
                .font(.apexHeading(size: 16, relativeTo: .headline))
                .tracking(4)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small accent button used on pictures, e.g. "Rezerviraj termin →".
struct ApexCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(Color.apexOnAccent)
        .padding(.horizontal, 14)
        .frame(minHeight: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.apexAccent)
        )
        .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview {
    ClientHomeView(selectedTab: .constant(.home), showsProgress: .constant(false))
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}
