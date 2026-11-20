//
//  TrainingSaveQueue.swift
//  ApexPerformance
//

import Foundation
import Network
import SwiftUI

/// Saves trainings from the training form. Without a connection the
/// training is kept on the device (it survives the app being closed) and
/// saved as soon as the connection is back or the app comes to the
/// foreground. The last saved state wins. A training the server rejects
/// stays on the device until the coach retries or discards it.
@MainActor
final class TrainingSaveQueue: ObservableObject {

    static let shared = TrainingSaveQueue()

    /// A training waiting to be saved.
    struct Entry: Codable, Identifiable {
        // The form's own id, so later saves of the same form replace it.
        let key: UUID
        // Logged user it belongs to; others' trainings are never sent.
        var userId: UUID?
        // Id the server gave the training; nil until it was created once.
        var trainingId: UUID?
        var request: SaveTrainingRequest
        // Start to mark once the training exists (a training started offline).
        var startedAt: Date?
        // Live Activity of the training, linked to it once it is saved.
        var activityKey: String?
        // The server's error when it rejected the training.
        var rejectedMessage: String?
        var updatedAt: Date
        // Session of clients training at the same time it belongs to
        // (TrainingSessionRegistry), so ending one ends all of them.
        var sessionKey: UUID? = nil

        var id: UUID { key }
    }

    enum Outcome {
        case saved(Training)
        // No connection: kept on the device, saved later.
        case queued
        case failed(Error)
    }

    /// A training saved from the queue, for a form that is still open.
    struct Synced: Equatable {
        let key: UUID
        let training: Training
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var lastSynced: Synced?
    // "Saved" shown for a moment after the queue saved trainings.
    @Published private(set) var showsSaved = false

    private var inFlight: Set<UUID> = []
    // Server ids of trainings saved in this run, by form key: a form that
    // saves again updates the training instead of creating another one.
    private var savedIds: [UUID: UUID] = [:]
    private let monitor = NWPathMonitor()
    private var isOnline = true
    private var isStarted = false

    private init() {
        entries = Self.read()
    }

    /// Saves the queue when the connection comes back.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in
                let shared = TrainingSaveQueue.shared
                let cameBack = online && !shared.isOnline
                shared.isOnline = online
                if cameBack { await shared.syncAll() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "TrainingSaveQueue.path"))
    }

    // MARK: - Saving

    /// Saves the training now; without a connection it is kept and saved later.
    /// startedAt marks a training that starts now as started once it exists.
    func save(key: UUID, request: SaveTrainingRequest, trainingId: UUID?, startedAt: Date?,
              activityKey: String?, sessionKey: UUID? = nil) async -> Outcome {
        await waitUntilIdle(key)

        let previous = entries.first { $0.key == key }
        let knownId = trainingId ?? previous?.trainingId ?? savedIds[key]
        var entry = Entry(
            key: key,
            userId: Self.currentUserId,
            trainingId: knownId,
            request: request,
            // A start not marked yet (the training was never created).
            startedAt: startedAt ?? previous?.startedAt,
            activityKey: activityKey ?? previous?.activityKey,
            rejectedMessage: nil,
            updatedAt: .now,
            sessionKey: sessionKey ?? previous?.sessionKey
        )
        remove(key)

        switch await send(&entry) {
        case .success(let training):
            return .saved(training)
        case .failure(let error):
            if error.isOffline {
                store(entry)
                return .queued
            }
            // Kept when something was waiting already or the training was
            // created half way (its start not marked), so nothing is lost.
            if previous != nil || entry.trainingId != knownId {
                entry.rejectedMessage = mapError(error)
                store(entry)
            }
            return .failed(error)
        }
    }

    /// Saves every waiting training that the server didn't reject.
    func syncAll() async {
        guard let userId = Self.currentUserId else { return }
        // Trainings of someone who logged out are not sent with another login.
        let others = entries.filter { $0.userId != nil && $0.userId != userId }
        others.forEach { discard($0.key) }

        for entry in entries where entry.rejectedMessage == nil {
            await retry(entry.key)
        }
    }

    /// Tries to save one waiting training again.
    func retry(_ key: UUID) async {
        guard !inFlight.contains(key), var entry = entries.first(where: { $0.key == key }) else { return }
        entry.rejectedMessage = nil
        store(entry)

        switch await send(&entry) {
        case .success(let training):
            remove(key)
            lastSynced = Synced(key: key, training: training)
            flashSaved()
        case .failure(let error):
            if !error.isOffline && !error.isCancellation {
                entry.rejectedMessage = mapError(error)
            }
            // Still here unless the form saved it in the meantime.
            if entries.contains(where: { $0.key == key }) {
                store(entry)
            }
        }
    }

    /// The form started its draft activity again (the old one went away):
    /// a waiting training links the new one once it is saved.
    func replaceActivityKey(_ old: String, with new: String) {
        guard let index = entries.firstIndex(where: { $0.activityKey == old }) else { return }
        entries[index].activityKey = new
        write()
    }

    /// Drops a waiting training, e.g. one the server keeps rejecting.
    func discard(_ key: UUID) {
        if let activityKey = entries.first(where: { $0.key == key })?.activityKey {
            TrainingLiveActivity.endDraft(activityKey)
        }
        remove(key)
    }

    private func send(_ entry: inout Entry) async -> Result<Training, Error> {
        inFlight.insert(entry.key)
        defer { inFlight.remove(entry.key) }

        do {
            var saved = try await Training.save(entry.request, id: entry.trainingId)
            // From now on the same training is updated, never created again.
            entry.trainingId = saved.id
            savedIds[entry.key] = saved.id
            entry.request.notifyClient = nil
            if let sessionKey = entry.sessionKey {
                TrainingSessionRegistry.add(saved.id, toSession: sessionKey)
            }
            if let start = entry.startedAt {
                // A session has one activity, linked to its first training;
                // the others don't start their own on this iPhone. The draft
                // is linked once the training is started, never before: a
                // training list loaded meanwhile would see it not started
                // and end the activity. Linking only updates the draft, also
                // in the background (locked phone), where iOS can't start
                // another one.
                let showsActivity = entry.sessionKey == nil || entry.activityKey != nil
                saved = try await saved.settingTimes(startedAt: start, endedAt: nil,
                                                     updatesActivity: showsActivity && entry.activityKey == nil)
                entry.startedAt = nil
                if let activityKey = entry.activityKey {
                    await TrainingLiveActivity.link(activityKey, to: saved)
                    entry.activityKey = nil
                }
            }
            return .success(saved)
        } catch {
            return .failure(error)
        }
    }

    private func waitUntilIdle(_ key: UUID) async {
        while inFlight.contains(key) {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func flashSaved() {
        withAnimation { showsSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            // Not while other trainings still wait.
            withAnimation { self.showsSaved = false }
        }
    }

    // MARK: - Storage

    private func store(_ entry: Entry) {
        if let index = entries.firstIndex(where: { $0.key == entry.key }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        write()
    }

    private func remove(_ key: UUID) {
        guard entries.contains(where: { $0.key == key }) else { return }
        entries.removeAll { $0.key == key }
        write()
    }

    private static var currentUserId: UUID? {
        KeychainService.shared.getToken().flatMap { JWTDecoder.getUserId(token: $0) }
    }

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pending-trainings.json")
    }

    private static func read() -> [Entry] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func write() {
        guard let url = Self.fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if entries.isEmpty {
                try? FileManager.default.removeItem(at: url)
            } else {
                try JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        } catch {
            print("Pending trainings not stored: \(error)")
        }
    }
}

extension Error {
    /// No connection (or it dropped): worth trying again later.
    var isOffline: Bool {
        guard let urlError = self as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }
}

/// Small banner about trainings kept on the device: waiting for the
/// connection, rejected by the server (Retry / Discard) or just saved.
struct TrainingSaveBanner: View {
    @ObservedObject private var queue = TrainingSaveQueue.shared

    var body: some View {
        Group {
            if let rejected = queue.entries.first(where: { $0.rejectedMessage != nil }) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("training_not_saved \(rejected.request.name)")
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: rejected.rejectedMessage ?? "")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    HStack(spacing: 8) {
                        Button {
                            Task { await queue.retry(rejected.key) }
                        } label: {
                            Text("retry")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.apexMainColor)

                        Button(role: .destructive) {
                            queue.discard(rejected.key)
                        } label: {
                            Text("discard")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .accessibilityIdentifier("training-save-rejected")
            } else if !queue.entries.isEmpty {
                Label("offline_will_save", systemImage: "wifi.slash")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("training-save-offline")
            } else if queue.showsSaved {
                Label {
                    Text("saved")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.apexBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1 : 0)
        .frame(height: isVisible ? nil : 0)
        .clipped()
        .animation(.easeInOut, value: isVisible)
        .accessibilityHidden(!isVisible)
    }

    private var isVisible: Bool {
        !queue.entries.isEmpty || queue.showsSaved
    }
}
