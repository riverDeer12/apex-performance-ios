//
//  TrainingSessionFormView.swift
//  ApexPerformance
//

import SwiftUI

/// New training form of the coach, for one client or for several clients
/// who train at the same time ("+ Client"): every client has their own
/// training (the usual training form, one per client, kept while switching),
/// all of them share one time. Save saves every training as a normal
/// training of its client; one that fails shows its error and Save tries
/// again. One Live Activity shows the session ("Ana, Marko").
struct TrainingSessionFormView: View {
    var onSaved: ((Training) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var session: TrainingSession
    // What every client's form starts with.
    @State private var seeds: [UUID: Seed]
    // The session's trainings in the save queue and on the device, so ending one ends all.
    @State private var sessionKey = UUID()
    @State private var saveRequest = 0
    // A training that starts with the save: its toast says so.
    @State private var startsOnSave = true
    // The session's Live Activity and the clients it was started with.
    @State private var activityKey: String?
    @State private var activityClients = ""
    // All trainings, loaded once a client is added, for their "last time" sets.
    @State private var allTrainings: [Training]?
    @State private var isPickingClient = false
    @State private var isAddingClient = false
    @State private var removing: TrainingSession.Participant?
    @State private var isConfirmingDiscard = false
    @ObservedObject private var saveQueue = TrainingSaveQueue.shared

    private struct Seed {
        let history: [Training]
        var copying: Training? = nil
    }

    init(client: Training.Person, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.onSaved = onSaved
        let first = TrainingSession.Participant(clientId: client.id, firstName: client.firstName,
                                                lastName: client.lastName, pictureUrl: client.pictureUrl)
        _session = State(initialValue: TrainingSession(first: first))
        _seeds = State(initialValue: [first.id: Seed(history: history)])
    }

    /// New training for the same client with the exercises and sets of the given one ("Copy training").
    init(copying source: Training, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.onSaved = onSaved
        let first = TrainingSession.Participant(clientId: source.client.id, firstName: source.client.firstName,
                                                lastName: source.client.lastName, pictureUrl: source.client.pictureUrl)
        _session = State(initialValue: TrainingSession(first: first))
        _seeds = State(initialValue: [first.id: Seed(history: history, copying: source)])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Every client's form stays, only the chosen one is shown.
                ForEach(session.participants) { participant in
                    let isActive = participant.id == session.activeId
                    form(for: participant)
                        .opacity(isActive ? 1 : 0)
                        .allowsHitTesting(isActive)
                        .accessibilityHidden(!isActive)
                        .zIndex(isActive ? 1 : 0)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    TrainingSaveBanner()
                    header
                }
                .padding(.vertical, 6)
                .background(Color(.systemGroupedBackground))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if session.isShared {
                    othersCard
                }
            }
            .confirmsDiscardingChanges(session.hasChanges, isConfirming: $isConfirmingDiscard) {
                dismiss()
            }
            .navigationTitle(session.isShared ? LocalizedStringKey("training_session") : LocalizedStringKey("new_training"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveAll()
                    } label: {
                        ZStack {
                            if session.isSaving {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                    }
                    .disabled(!session.canSave)
                    .accessibilityIdentifier("training-session-save")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // Asked once for all trainings of the session.
                        if session.hasChanges {
                            isConfirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityIdentifier("training-form-close")
                }
            }
            .sheet(isPresented: $isPickingClient) {
                ClientPickerView(title: "add_client_to_session") { client in
                    isPickingClient = false
                    Task { await add(client) }
                }
            }
            .onChange(of: activityWish) { _, _ in updateActivity() }
            .onDisappear {
                // Closed without anything saved: nothing runs.
                if let activityKey, !session.isPersisted {
                    TrainingLiveActivity.endDraft(activityKey)
                }
            }
        }
    }

    // MARK: - Forms

    private func form(for participant: TrainingSession.Participant) -> some View {
        let id = participant.id
        let context = TrainingSessionContext(
            sessionKey: sessionKey,
            startedAt: session.startedAt,
            isShared: session.isShared,
            activityKey: id == session.leader.id ? activityKey : nil,
            saveRequest: saveRequest,
            onStart: {
                session.start(at: .now)
            },
            onReport: { report in
                session.update(id) { participant in
                    participant.trainingName = report.trainingName
                    participant.enteredSets = report.enteredSets
                    participant.lastSet = report.lastSet
                    participant.hasChanges = report.hasChanges
                    participant.isValid = report.isValid
                    participant.startsOnSave = report.startsOnSave
                    participant.saved = report.saved
                    participant.isQueued = report.isQueued
                    participant.queueKey = report.queueKey
                }
            },
            onSaveOutcome: { outcome in
                record(outcome, for: id)
            }
        )
        let seed = seeds[id] ?? Seed(history: [])
        return Group {
            if let copying = seed.copying {
                TrainingFormView(copying: copying, history: seed.history, session: context, onSaved: onSaved)
            } else {
                TrainingFormView(clientId: participant.clientId, history: seed.history, session: context,
                                 onSaved: onSaved)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if session.isShared {
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("training_session_hint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(verbatim: session.headerNames)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if let startedAt = session.startedAt {
                        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                            .accessibilityLabel(Text("training_in_progress"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 8) {
                    switcher
                    addClientButton(compact: true)
                }
            }
            .padding(.horizontal, 16)
            .confirmationDialog("remove_client_question", isPresented: isConfirmingRemoval,
                                titleVisibility: .visible, presenting: removing) { participant in
                Button("remove_client", role: .destructive) {
                    Task { await remove(participant) }
                }
                Button("cancel", role: .cancel) {}
            } message: { participant in
                Text("remove_client_info \(participant.fullName)")
            }
        } else {
            // One client: whose training it is, and another client can join.
            HStack(spacing: 12) {
                UserNameLabel(name: session.leader.fullName, pictureUrl: session.leader.pictureUrl)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                addClientButton(compact: false)
            }
            .padding(.horizontal, 20)
        }
    }

    /// One segment per client: "Ana · Upper body"; held, it can remove the client.
    /// Two share the width, more scroll.
    @ViewBuilder
    private var switcher: some View {
        if session.participants.count <= 2 {
            HStack(spacing: 0) {
                ForEach(session.participants) { segment($0) }
            }
            .padding(4)
            .background(Color(.tertiarySystemFill), in: Capsule())
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(session.participants) { participant in
                            segment(participant)
                                .id(participant.id)
                        }
                    }
                    .padding(4)
                }
                .background(Color(.tertiarySystemFill), in: Capsule())
                .onChange(of: session.activeId) { _, id in
                    withAnimation { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func segment(_ participant: TrainingSession.Participant) -> some View {
        let isActive = participant.id == session.activeId
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { session.select(participant.id) }
        } label: {
            HStack(spacing: 6) {
                UserAvatarView(name: participant.fullName, pictureUrl: participant.pictureUrl, size: 22)
                Text(verbatim: session.segmentLabel(participant))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.subheadline.weight(isActive ? .bold : .semibold))
            .foregroundStyle(isActive ? Color.apexMainColor : Color.secondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .frame(maxWidth: session.participants.count <= 2 ? .infinity : 220)
            .background {
                if isActive {
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                requestRemoval(participant)
            } label: {
                Label("remove_client", systemImage: "person.badge.minus")
            }
            .disabled(!session.canRemove(participant.id))
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityAction(named: Text("remove_client")) {
            requestRemoval(participant)
        }
        .accessibilityIdentifier("training-session-segment")
    }

    private func addClientButton(compact: Bool) -> some View {
        Button {
            isPickingClient = true
        } label: {
            Group {
                if isAddingClient {
                    ProgressView()
                } else if compact {
                    Image(systemName: "person.badge.plus")
                        .accessibilityLabel(Text("add_client_to_session"))
                } else {
                    Label("add_client_short", systemImage: "plus")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.apexMainColor)
            .padding(.horizontal, compact ? 10 : 12)
            .frame(minWidth: 44, minHeight: 36)
            .background(Color.apexMainColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isAddingClient || session.isSaving)
        .accessibilityIdentifier("training-session-add-client")
    }

    /// Under the shown client's exercises: what the others do, a tap shows their training.
    private var othersCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 6) {
                ForEach(session.others) { other in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { session.select(other.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text(verbatim: Self.otherLine(other, now: context.date))
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("training-session-other")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    /// "Marko: last set 2 min ago (Squat 3/4)", "Marko: no sets yet".
    static func otherLine(_ participant: TrainingSession.Participant, now: Date) -> String {
        guard let lastSet = participant.lastSet else {
            return String(localized: "training_session_no_sets \(participant.shortName)")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        // Under a minute reads "just now" rather than "in 0 sec".
        let ago = now.timeIntervalSince(lastSet.at) < 60
            ? String(localized: "just_now")
            : formatter.localizedString(for: lastSet.at, relativeTo: now)
        return String(localized: "training_session_last_set \(participant.shortName) \(ago) \(lastSet.summary)")
    }

    // MARK: - Clients

    private var isConfirmingRemoval: Binding<Bool> {
        Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
    }

    private func requestRemoval(_ participant: TrainingSession.Participant) {
        guard session.canRemove(participant.id) else { return }
        if session.needsConfirmationToRemove(participant.id) {
            removing = participant
        } else {
            Task { await remove(participant) }
        }
    }

    @MainActor
    private func add(_ client: Client) async {
        guard !session.contains(clientId: client.id) else {
            toastManager.show("client_already_in_session", type: .info)
            return
        }
        isAddingClient = true
        defer { isAddingClient = false }
        // Their earlier trainings give "last time" and "repeat last training";
        // the form works without them.
        if allTrainings == nil {
            allTrainings = try? await Training.loadAll()
        }
        let participant = TrainingSession.Participant(clientId: client.id, firstName: client.firstName,
                                                      lastName: client.lastName, pictureUrl: client.pictureUrl)
        seeds[participant.id] = Seed(history: (allTrainings ?? []).filter { $0.client.id == client.id })
        withAnimation {
            _ = session.add(participant)
        }
    }

    /// A training saved already (e.g. autosaved in the background) is deleted;
    /// one kept on the device is dropped.
    @MainActor
    private func remove(_ removed: TrainingSession.Participant) async {
        // As it is now, it may have been autosaved since it was asked.
        let participant = session.participant(removed.id) ?? removed
        guard session.canRemove(participant.id) else { return }
        if let saved = participant.saved {
            do {
                try await Training.delete(id: saved.id)
            } catch {
                toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
                return
            }
        }
        if participant.isQueued, let queueKey = participant.queueKey {
            saveQueue.discard(queueKey)
        }
        withAnimation {
            _ = session.remove(participant.id)
        }
        seeds[participant.id] = nil
    }

    // MARK: - Save

    private func saveAll() {
        startsOnSave = session.participants.contains(where: \.startsOnSave)
        guard !session.beginSaveAll().isEmpty else { return }
        saveRequest += 1
    }

    private func record(_ outcome: TrainingSession.SaveOutcome, for id: UUID) {
        guard let result = session.record(outcome, for: id) else { return }
        switch result {
        case .saved(let anyQueued):
            if anyQueued {
                toastManager.show("offline_will_save", type: .info)
            } else {
                toastManager.show(startsOnSave ? "training_started_toast" : "training_saved_successfully",
                                  type: .success)
            }
            dismiss()
        case .failed(let ids):
            // The others are saved; the first one that isn't is shown with its error.
            guard let first = ids.first, let participant = session.participant(first) else { return }
            withAnimation { session.select(first) }
            let message = session.failureMessage(first) ?? ""
            toastManager.show("training_not_saved_for \(participant.shortName) \(message)", type: .error)
        }
    }

    // MARK: - Live Activity

    /// What the session's activity shows: it runs once the time started,
    /// unless the first client's training is planned or completed.
    private struct ActivityWish: Equatable {
        let startedAt: Date?
        let runs: Bool
        let clients: String
        let name: String
        let leaderSaved: Training?
    }

    private var activityWish: ActivityWish {
        ActivityWish(startedAt: session.startedAt, runs: session.leader.startsOnSave || session.leader.saved != nil,
                     clients: session.activityClientNames, name: session.leader.trainingName,
                     leaderSaved: session.leader.saved)
    }

    private func updateActivity() {
        let wish = activityWish
        guard let startedAt = wish.startedAt else { return }

        guard wish.runs else {
            if let activityKey, !session.isPersisted {
                TrainingLiveActivity.endDraft(activityKey)
                self.activityKey = nil
            }
            return
        }

        if let activityKey, activityClients != wish.clients {
            // A client joined or left: the clients are fixed when an activity
            // starts, so a new one takes its place (linked if the training is saved).
            TrainingLiveActivity.endDraft(activityKey)
            self.activityKey = nil
        }

        if let activityKey {
            TrainingLiveActivity.renameDraft(activityKey, name: wish.name)
            return
        }

        activityKey = TrainingLiveActivity.startDraft(name: wish.name, clientName: wish.clients, startedAt: startedAt)
        activityClients = wish.clients
        if let key = activityKey, let saved = wish.leaderSaved, saved.startedAt != nil {
            Task { await TrainingLiveActivity.link(key, to: saved) }
        }
    }
}
