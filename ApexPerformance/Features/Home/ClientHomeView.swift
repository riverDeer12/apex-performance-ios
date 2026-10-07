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
    @State private var hasLoaded = false
    @State private var showCreateAppointment = false
    @State private var goal: ClientGoal?
    @State private var showGoalSheet = false

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
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await load()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ApexTitleBar(subtitle: ClientPlan.title(for: client?.plan))
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
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                }
                Text("ready_for_next_training")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var nextAppointmentCard: some View {
        ApexPictureBackground(systemImage: "figure.strengthtraining.traditional")
            .frame(height: 210)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let appointment = nextAppointment {
                            Text(appointment.isPending
                                 ? LocalizedStringKey("next_appointment_pending")
                                 : LocalizedStringKey("next_appointment"))
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.8))

                            Text(verbatim: Self.dateAndTime(appointment.startTime))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        } else if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("no_upcoming_appointments")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                                .textCase(.uppercase)
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer(minLength: 0)

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
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack {
                    Text("package_done_of_total \(package.done) \(package.total)")
                    Spacer()
                    Text("package_remaining \(package.remaining)")
                }
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

                ApexProgressBar(value: package.progress)
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
            HStack(spacing: 14) {
                Image(systemName: "scope")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.apexAccent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("my_goal_and_plan")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .padding(.bottom, 2)

                    Group {
                        goalLine("goal_line \(goal.goal ?? "")", isEmpty: goal.goal)
                        goalLine("current_block_line \(goal.currentBlock ?? "")", isEmpty: goal.currentBlock)
                        goalLine("focus_line \(goal.focus ?? "")", isEmpty: goal.focus)
                        if let date = goal.nextAssessmentDate {
                            Text("next_assessment_line \(DateFormatter.dateWithDots.string(from: date))")
                        } else if let text = goal.nextAssessment, !text.isEmpty {
                            Text("next_assessment_line \(text)")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
    private func goalLine(_ text: LocalizedStringKey, isEmpty value: String?) -> some View {
        if let value, !value.isEmpty {
            Text(text)
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
                .frame(width: 26)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
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
        let isPending: Bool
    }

    /// Next approved appointment, or the next one waiting for approval.
    private var nextAppointment: NextAppointment? {
        let now = Date()
        if let approved = approvedAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: approved.startTime, isPending: false)
        }
        if let pending = pendingAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: pending.startTime, isPending: true)
        }
        return nil
    }

    // For example "8.10.2026. 18:00".
    static func dateAndTime(_ date: Date) -> String {
        "\(DateFormatter.dateWithDots.string(from: date)) \(date.formatted(date: .omitted, time: .shortened))"
    }

    @MainActor
    private func load() async {
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
                .font(.system(size: 17, weight: .heavy))
                .tracking(4)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small accent button used on pictures, e.g. "REZERVIRAJ TERMIN →".
struct ApexCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.label
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Color.apexOnAccent)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
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
