//
//  ClientHomeView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's home: next appointment with booking, trainings done this
/// month and shortcuts to trainings and progress.
struct ClientHomeView: View {
    @Binding var selectedTab: AppTab
    // Set from outside (e.g. a body measurement notification) to open progress.
    @Binding var showsProgress: Bool

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager

    @State private var client: UserProfile?
    @State private var approvedAppointments: [Appointment] = []
    @State private var pendingAppointments: [Appointment] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var showCreateAppointment = false
    @State private var goal: ClientGoal?
    @State private var monthlyReviews: [MonthlyReview] = []
    @State private var showGoalSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let goal, !goal.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("my_goal_and_plan")
                                .apexLabel()
                            ClientGoalContentView(goal: goal)
                        }
                        .padding(16)
                        .apexCardBackground()
                        .accessibilityIdentifier("goal-card")
                    }

                    nextAppointmentCard

                    if canGetAppointments {
                        Button("book_appointment") {
                            showCreateAppointment = true
                        }
                        .buttonStyle(ApexPrimaryButtonStyle())
                        .accessibilityIdentifier("book-appointment-button")
                    }

                    thisMonth

                    HStack(spacing: 12) {
                        Button {
                            selectedTab = .trainings
                        } label: {
                            tile(title: "my_trainings", systemImage: "dumbbell")
                        }
                        .buttonStyle(.plain)

                        Button {
                            showsProgress = true
                        } label: {
                            tile(title: "progress", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("progress-tile")
                    }

                    // Workout library depends on the plan agreed with the coach.
                    let access = WorkoutLibraryAccess(plan: client?.plan)
                    if access != .none {
                        NavigationLink {
                            WorkoutsView(
                                workoutFilter: access.allows,
                                title: access == .all ? "exercise_library" : "mobility_and_stretching",
                                subtitle: access == .all ? "exercise_library_subtitle" : "mobility_and_stretching_subtitle",
                                wrapsInNavigationStack: false
                            )
                        } label: {
                            tile(
                                title: access == .all ? "exercise_library" : "mobility_and_stretching",
                                systemImage: access == .all ? "figure.strengthtraining.functional" : "figure.flexibility"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library-tile")
                    }

                    latestReviewCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
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

    // MARK: - Monthly review

    @ViewBuilder
    private var latestReviewCard: some View {
        if let review = monthlyReviews.first {
            NavigationLink {
                MonthlyReviewsView(reviews: monthlyReviews)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("monthly_review")
                            .apexLabel()
                        Spacer()
                        MonthTitle(date: review.monthDate)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: review.content)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text("all_monthly_reviews")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.apexAccent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .apexCardBackground()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("monthly-review-card")
        }
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "APEX")
                .font(.system(size: 13, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.secondary)

            if let firstName = client?.firstName, !firstName.isEmpty {
                Text("hello_name \(firstName)")
                    .apexLabel()
            }

            Text(ClientPlan.title(for: client?.plan) ?? "tab_home")
                .apexTitle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextAppointmentCard: some View {
        ApexPictureBackground(systemImage: "figure.strengthtraining.traditional")
            .frame(height: 190)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    if let appointment = nextAppointment {
                        Text(appointment.isPending ? LocalizedStringKey("next_appointment_pending") : LocalizedStringKey("next_appointment"))
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.75))

                        Text(appointment.startTime, format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(size: 18, weight: .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)

                        Text(verbatim: appointment.timeSlot.description ?? "")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.apexAccent)
                    } else if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("no_upcoming_appointments")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private var thisMonth: some View {
        let (done, total) = thisMonthCounts

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("this_month")
                    .apexLabel()
                Spacer()
                if let credits = client?.credits {
                    Text("credits_left \(credits)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("trainings_done_of_total \(done) \(total)")
                .font(.system(size: 15, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)

            ApexProgressBar(value: total > 0 ? Double(done) / Double(total) : 0)
        }
        .padding(16)
        .apexCardBackground()
    }

    private func tile(title: LocalizedStringKey, systemImage: String) -> some View {
        ApexPictureBackground(systemImage: systemImage)
            .frame(height: 120)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
    }

    // MARK: - Data

    private var canGetAppointments: Bool {
        authManager.hasPermission(permission: Permissions.canGetAppointments)
    }

    private struct NextAppointment {
        let startTime: Date
        let timeSlot: TimeSlot
        let isPending: Bool
    }

    /// Next approved appointment, or the next one waiting for approval.
    private var nextAppointment: NextAppointment? {
        let now = Date()
        if let approved = approvedAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: approved.startTime, timeSlot: approved.timeSlot, isPending: false)
        }
        if let pending = pendingAppointments
            .filter({ $0.startTime > now })
            .min(by: { $0.startTime < $1.startTime }) {
            return NextAppointment(startTime: pending.startTime, timeSlot: pending.timeSlot, isPending: true)
        }
        return nil
    }

    /// Approved appointments this month that are over, and all of them.
    private var thisMonthCounts: (done: Int, total: Int) {
        let now = Date()
        let thisMonth = approvedAppointments.filter {
            Calendar.current.isDate($0.startTime, equalTo: now, toGranularity: .month)
        }
        return (thisMonth.filter { $0.endTime < now }.count, thisMonth.count)
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

        // Goal and reviews are extras, home works without them.
        if let loadedGoal = try? await ClientGoal.loadMine() {
            goal = loadedGoal
            showGoalIfChanged()
        }
        if let reviews = try? await MonthlyReview.load() {
            monthlyReviews = reviews
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

#Preview {
    ClientHomeView(selectedTab: .constant(.home), showsProgress: .constant(false))
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}
