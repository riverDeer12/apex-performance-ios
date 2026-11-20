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
    @Environment(\.scenePhase) private var scenePhase
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
    // A saved session opened to edit: its trainings are edited together.
    private var isEditing = false
    // When the edited session ended; clients added to it get the same times.
    @State private var endedAt: Date?
    @ObservedObject private var saveQueue = TrainingSaveQueue.shared

    private struct Seed {
        let history: [Training]
        var copying: Training? = nil
        // The saved training this client's form edits.
        var training: Training? = nil
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

    /// A saved session (trainings of clients who trained at the same time)
    /// opened to edit, with the tapped training's client shown.
    init(editing trainings: [Training], selected: UUID, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.onSaved = onSaved
        isEditing = true
        var seeds: [UUID: Seed] = [:]
        var participants: [TrainingSession.Participant] = []
        var selectedParticipant: UUID?
        for training in trainings {
            var participant = TrainingSession.Participant(clientId: training.client.id,
                                                          firstName: training.client.firstName,
                                                          lastName: training.client.lastName,
                                                          pictureUrl: training.client.pictureUrl)
            participant.existing = training
            participant.trainingName = training.name
            participant.isValid = true
            participant.startsOnSave = false
            if training.id == selected { selectedParticipant = participant.id }
            participants.append(participant)
            seeds[participant.id] = Seed(history: history.filter { $0.client.id == training.client.id },
                                         training: training)
        }
        let first = trainings.first { $0.startedAt != nil }
        let session = TrainingSession(editing: participants, selected: selectedParticipant, startedAt: first?.startedAt)
            ?? TrainingSession(first: TrainingSession.Participant(clientId: UUID(), firstName: nil, lastName: nil))
        _session = State(initialValue: session)
        _seeds = State(initialValue: seeds)
        _endedAt = State(initialValue: first?.endedAt)
        // Trainings saved before the session id get it with this save.
        _sessionKey = State(initialValue: trainings.compactMap(\.sessionId).first ?? UUID())
        _allTrainings = State(initialValue: history.isEmpty ? nil : history)
    }

    private var title: LocalizedStringKey {
        if session.isShared { return "training_session" }
        return isEditing ? "edit_training" : "new_training"
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
            .navigationTitle(title)
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
            // The activity may have gone while the phone was locked.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { updateActivity(restartsDraft: true) }
            }
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
            if let training = seed.training {
                TrainingFormView(clientId: participant.clientId, training: training, history: seed.history,
                                 session: context, onSaved: onSaved)
            } else if let copying = seed.copying {
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
                    if let startedAt = session.startedAt, let endedAt {
                        // An ended session (edited later): its times.
                        Text(verbatim: "\(startedAt.formatted(date: .omitted, time: .shortened))–\(endedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else if let startedAt = session.startedAt {
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
                if let existing = participant.existing {
                    // A saved training: closing its tab changes nothing of it.
                    Button("close_client_tab") {
                        Task { await remove(participant) }
                    }
                    Button("remove_from_session") {
                        Task { await detach(participant, existing) }
                    }
                    Button("delete_training", role: .destructive) {
                        Task { await delete(participant, existing) }
                    }
                } else {
                    Button("remove_client", role: .destructive) {
                        Task { await remove(participant) }
                    }
                }
                Button("cancel", role: .cancel) {}
            } message: { participant in
                if participant.existing != nil {
                    Text("remove_saved_client_info \(participant.fullName)")
                } else {
                    Text("remove_client_info \(participant.fullName)")
                }
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

    /// Takes a saved training out of the session (it stays as a training on
    /// its own, as it was last saved) and closes its tab.
    @MainActor
    private func detach(_ participant: TrainingSession.Participant, _ training: Training) async {
        do {
            let saved = try await Training.save(training.saveRequest(sessionId: TrainingSession.noSession), id: training.id)
            onSaved?(saved)
            close(participant)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    /// Deletes a saved training of the session and closes its tab.
    @MainActor
    private func delete(_ participant: TrainingSession.Participant, _ training: Training) async {
        do {
            try await Training.delete(id: training.id)
            close(participant)
            toastManager.show("training_deleted_successfully", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private func close(_ participant: TrainingSession.Participant) {
        withAnimation {
            _ = session.remove(participant.id)
        }
        seeds[participant.id] = nil
    }

    /// A new training saved already (e.g. autosaved in the background) is deleted;
    /// one kept on the device is dropped. A saved one being edited only closes.
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
            // Clients added to an ended session get its times too.
            if let startedAt = session.startedAt, let endedAt {
                let added = session.participants.filter { $0.existing == nil }.compactMap(\.saved)
                    .filter { $0.endedAt == nil }
                Task {
                    for training in added {
                        if let updated = try? await training.settingTimes(startedAt: startedAt, endedAt: endedAt,
                                                                           updatesActivity: false) {
                            onSaved?(updated)
                        }
                    }
                }
            }
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

    /// `restartsDraft`: the app came back to the foreground, the draft is
    /// started again if it went away meanwhile.
    private func updateActivity(restartsDraft: Bool = false) {
        let wish = activityWish
        guard let startedAt = wish.startedAt else { return }

        guard wish.runs else {
            if let activityKey, !session.isPersisted {
                TrainingLiveActivity.endDraft(activityKey)
                self.activityKey = nil
            }
            return
        }

        // iOS starts activities only in the foreground: in the background
        // (e.g. the leader's training autosaved when the phone was locked)
        // the activity is only updated, never ended to start another one.
        let isForeground = UIApplication.shared.applicationState == .active

        if let activityKey, activityClients != wish.clients, isForeground {
            // A client joined or left: the clients are fixed when an activity
            // starts, so a new one takes its place (linked if the training is saved).
            TrainingLiveActivity.endDraft(activityKey)
            self.activityKey = nil
        }

        if let key = activityKey {
            // Not saved yet and its activity went away: started again. A saved
            // one is started again by its training (TrainingLiveActivity.reconcile).
            if restartsDraft, wish.leaderSaved == nil {
                let current = TrainingLiveActivity.restartDraftIfNeeded(
                    key, isRunning: true, name: wish.name, clientName: wish.clients, startedAt: startedAt)
                if current != key {
                    activityKey = current
                    activityClients = wish.clients
                    return
                }
            }
            TrainingLiveActivity.renameDraft(key, name: wish.name)
            return
        }

        guard isForeground else { return }
        activityKey = TrainingLiveActivity.startDraft(name: wish.name, clientName: wish.clients, startedAt: startedAt)
        activityClients = wish.clients
        if let key = activityKey, let saved = wish.leaderSaved, saved.startedAt != nil {
            Task { await TrainingLiveActivity.link(key, to: saved) }
        }
    }
}

/// Edit of a saved training. A training of a session (clients who trained at
/// the same time with the coach) opens the session with all its trainings and
/// the tapped client shown; any other training (or an API without sessions)
/// opens the usual form. Clients never see the session.
struct TrainingEditView: View {
    let training: Training
    let history: [Training]
    // The session's trainings when the caller loaded them already.
    var preloaded: [Training]? = nil
    var onSaved: ((Training) -> Void)? = nil

    @EnvironmentObject private var authManager: AuthManager
    @State private var sessionTrainings: [Training]?
    @State private var sessionHistory: [Training] = []
    @State private var isLoaded = false

    private var isStaff: Bool {
        !authManager.hasRole(role: "Client")
    }

    var body: some View {
        Group {
            if !isLoaded {
                NavigationStack {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            } else if let sessionTrainings, TrainingSession.opensAsSession(sessionTrainings, isStaff: isStaff) {
                TrainingSessionFormView(editing: sessionTrainings, selected: training.id, history: sessionHistory,
                                        onSaved: onSaved)
            } else {
                TrainingFormView(clientId: training.client.id, training: training, history: history, onSaved: onSaved)
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        guard !isLoaded else { return }
        defer { isLoaded = true }
        guard isStaff, TrainingSession.mayHaveSession(training) else { return }
        var loaded = preloaded
        if loaded == nil {
            loaded = try? await Training.loadSession(of: training.id)
        }
        guard let trainings = loaded, trainings.count > 1 else { return }
        // "Last time" of every client of the session; without it the forms still work.
        sessionHistory = (try? await Training.loadAll()) ?? history
        sessionTrainings = trainings
    }
}
