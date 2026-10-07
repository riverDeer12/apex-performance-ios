//
//  ClientGoalViews.swift
//  ApexPerformance
//

import SwiftUI

// MARK: - Goal and plan

/// Sections of the client's goal and plan: goal, current block,
/// focus and next assessment. Empty sections are hidden.
struct ClientGoalContentView: View {
    let goal: ClientGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("goal", systemImage: "scope", text: goal.goal)
            section("current_block", systemImage: "calendar", text: goal.currentBlock)
            section("focus", systemImage: "target", text: goal.focus)

            if !(goal.nextAssessment ?? "").isEmpty || goal.nextAssessmentDate != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Label("next_assessment", systemImage: "checkmark.seal")
                        .apexLabel()
                    if let date = goal.nextAssessmentDate {
                        Text(verbatim: DateFormatter.dateWithDots.string(from: date))
                            .font(.subheadline.weight(.semibold))
                    }
                    if let text = goal.nextAssessment, !text.isEmpty {
                        Text(verbatim: text)
                            .font(.subheadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, systemImage: String, text: String?) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                    .apexLabel()
                Text(verbatim: text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Coach writes the client's goal and plan.
struct ClientGoalFormView: View {
    let clientId: UUID
    var onSaved: ((ClientGoal) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var goal: String
    @State private var currentBlock: String
    @State private var focus: String
    @State private var nextAssessment: String
    @State private var hasNextAssessmentDate: Bool
    @State private var nextAssessmentDate: Date
    @State private var isSaving = false

    init(clientId: UUID, goal: ClientGoal, onSaved: ((ClientGoal) -> Void)? = nil) {
        self.clientId = clientId
        self.onSaved = onSaved
        _goal = State(initialValue: goal.goal ?? "")
        _currentBlock = State(initialValue: goal.currentBlock ?? "")
        _focus = State(initialValue: goal.focus ?? "")
        _nextAssessment = State(initialValue: goal.nextAssessment ?? "")
        _hasNextAssessmentDate = State(initialValue: goal.nextAssessmentDate != nil)
        _nextAssessmentDate = State(initialValue: goal.nextAssessmentDate ?? .now)
    }

    private var isValid: Bool {
        goal.count <= 1000 && currentBlock.count <= 1000 && focus.count <= 1000 && nextAssessment.count <= 500
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("goal") {
                    TextField("goal_placeholder", text: $goal, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("current_block") {
                    TextField("current_block_placeholder", text: $currentBlock, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("focus") {
                    TextField("focus_placeholder", text: $focus, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section("next_assessment") {
                    Toggle("next_assessment_date", isOn: $hasNextAssessmentDate)
                        .tint(Color.apexMainColor)
                    if hasNextAssessmentDate {
                        DatePicker("date", selection: $nextAssessmentDate, displayedComponents: .date)
                    }
                    TextField("next_assessment_placeholder", text: $nextAssessment, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("goal_and_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let request = ClientGoal(
            goal: Self.clean(goal),
            currentBlock: Self.clean(currentBlock),
            focus: Self.clean(focus),
            nextAssessment: Self.clean(nextAssessment),
            nextAssessmentDate: hasNextAssessmentDate ? nextAssessmentDate : nil
        )

        do {
            let saved = try await request.save(clientId: clientId)
            onSaved?(saved)
            toastManager.show("goal_saved_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private static func clean(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Client's goal and plan on its own screen, opened from home.
struct ClientGoalDetailView: View {
    let goal: ClientGoal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ApexScreenHeader(title: "my_goal_and_plan", showsWordmark: false)

                ClientGoalContentView(goal: goal)
                    .padding(16)
                    .apexCardBackground()

                if let updatedAt = goal.updatedAt {
                    Text("updated_on \(DateFormatter.dateWithDots.string(from: updatedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shown to the client after login when the coach changed the goal and plan.
struct ClientGoalSheet: View {
    let goal: ClientGoal

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ApexScreenHeader(title: "my_goal_and_plan", subtitle: "my_goal_and_plan_subtitle")

                    ClientGoalContentView(goal: goal)
                        .padding(16)
                        .apexCardBackground()

                    Button("got_it") {
                        dismiss()
                    }
                    .buttonStyle(ApexPrimaryButtonStyle(systemImage: "checkmark"))
                }
                .padding(20)
            }
            .background(Color.apexBackground)
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Monthly reviews

/// Month name and year of a review, e.g. "Listopad 2026".
struct MonthTitle: View {
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.month(.wide).year())
            .textCase(.uppercase)
    }
}

/// Client's monthly reviews, newest first.
struct MonthlyReviewsView: View {
    let reviews: [MonthlyReview]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ApexScreenHeader(title: "monthly_reviews", subtitle: "monthly_reviews_subtitle")

                if reviews.isEmpty {
                    CardView {
                        Text("no_monthly_reviews")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                ForEach(reviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        MonthTitle(date: review.monthDate)
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1)
                        Text(verbatim: review.content)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .apexCardBackground()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Coach writes or edits the review of a client's month.
struct MonthlyReviewFormView: View {
    let clientId: UUID
    // Client's existing reviews, the form loads the one of the chosen month.
    let reviews: [MonthlyReview]
    var onChanged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var year: Int
    @State private var month: Int
    @State private var content: String
    @State private var isSaving = false
    @State private var showDeleteDialog = false

    init(clientId: UUID, reviews: [MonthlyReview], review: MonthlyReview? = nil, onChanged: (() -> Void)? = nil) {
        self.clientId = clientId
        self.reviews = reviews
        self.onChanged = onChanged
        // A new review is for the current month, written before the 1st.
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        _year = State(initialValue: review?.year ?? now.year ?? 2026)
        _month = State(initialValue: review?.month ?? now.month ?? 1)
        _content = State(initialValue: review?.content ?? "")
    }

    private var existingReview: MonthlyReview? {
        reviews.first { $0.year == year && $0.month == month }
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var years: [Int] {
        let current = Calendar.current.component(.year, from: .now)
        return Array(Set([current - 1, current, current + 1, year])).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("month", selection: $month) {
                        ForEach(1...12, id: \.self) { month in
                            Text(Self.monthDate(year: year, month: month), format: .dateTime.month(.wide))
                                .tag(month)
                        }
                    }
                    Picker("year", selection: $year) {
                        ForEach(years, id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                }

                Section {
                    TextField("monthly_review_placeholder", text: $content, axis: .vertical)
                        .lineLimit(8...20)
                } footer: {
                    Text(verbatim: "\(content.count) / 4000")
                }

                if let existingReview {
                    Section {
                        Button("delete_monthly_review", role: .destructive) {
                            showDeleteDialog = true
                        }
                        .disabled(isSaving)
                    } footer: {
                        Text("monthly_review_exists \(DateFormatter.dateWithDots.string(from: existingReview.updatedAt))")
                    }
                }
            }
            .navigationTitle("monthly_review")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: month) { _, _ in loadExisting() }
            .onChange(of: year) { _, _ in loadExisting() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .disabled(isSaving || trimmedContent.isEmpty || content.count > 4000)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
            .confirmationDialog("delete_monthly_review_question", isPresented: $showDeleteDialog,
                                titleVisibility: .visible) {
                Button("delete", role: .destructive) {
                    Task { await delete() }
                }
                Button("cancel", role: .cancel) {}
            }
        }
    }

    private static func monthDate(year: Int, month: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }

    // Switching the month shows that month's review, if written.
    private func loadExisting() {
        content = existingReview?.content ?? ""
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await MonthlyReview.save(clientId: clientId, year: year, month: month, content: trimmedContent)
            onChanged?()
            toastManager.show("monthly_review_saved_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func delete() async {
        guard let existingReview else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await MonthlyReview.delete(id: existingReview.id)
            onChanged?()
            toastManager.show("monthly_review_deleted_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

#Preview("Goal") {
    ClientGoalSheet(goal: ClientGoal(
        goal: "Lose 5 kg and run 10 km under 50 minutes.",
        currentBlock: "Strength base: 3 trainings a week, full body.",
        focus: "Hip mobility and squat depth.",
        nextAssessment: "FMS and body measurements",
        nextAssessmentDate: .now.addingTimeInterval(86_400 * 20)
    ))
}
