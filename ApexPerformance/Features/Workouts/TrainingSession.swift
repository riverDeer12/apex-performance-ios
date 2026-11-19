//
//  TrainingSession.swift
//  ApexPerformance
//

import Foundation

/// Trainings of clients who train at the same time with the coach
/// ("Separate trainings, one time"): every client has their own training
/// (name, exercises, sets, notes), all of them share one time. Each training
/// is saved as a normal training of its client, so history, progress,
/// records and packages work as before. The state of the session form
/// (TrainingSessionFormView) without SwiftUI, so it is unit tested.
struct TrainingSession {

    /// One client of the session and what their training form reports.
    struct Participant: Identifiable, Equatable {
        // The form's own id, not the client's.
        let id: UUID
        let clientId: UUID
        let firstName: String
        let lastName: String
        var pictureUrl: String? = nil

        var trainingName = ""
        // Sets with something entered (reps, weight, time or distance).
        var enteredSets = 0
        var lastSet: SetActivity? = nil
        var hasChanges = false
        // Name written and every exercise complete: the session can be saved.
        var isValid = false
        // Not planned and not completed: started with the session's time.
        var startsOnSave = true
        // The training already exists on the server (autosaved or saved).
        var saved: Training? = nil
        // Kept on the device to be saved when the connection is back.
        var isQueued = false
        // The form's key in the save queue.
        var queueKey: UUID? = nil

        init(id: UUID = UUID(), clientId: UUID, firstName: String?, lastName: String?, pictureUrl: String? = nil) {
            self.id = id
            self.clientId = clientId
            self.firstName = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.lastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.pictureUrl = pictureUrl
        }

        var fullName: String {
            [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        }

        // "Ana"; the last name when there is no first name.
        var shortName: String {
            firstName.isEmpty ? fullName : firstName
        }

        /// Saved or kept on the device: closing the form loses nothing of it.
        var isPersisted: Bool {
            saved != nil || isQueued
        }
    }

    /// The set entered last in a training, for the line about the other client:
    /// "Marko: last set 2 min ago (Squat 3/4)".
    struct SetActivity: Equatable {
        let at: Date
        let exerciseName: String
        // Sets of the exercise with something entered, and all its sets.
        let enteredSets: Int
        let setCount: Int

        // "Squat 3/4", "3/4" without the exercise's name.
        var summary: String {
            let count = "\(enteredSets)/\(setCount)"
            return exerciseName.isEmpty ? count : "\(exerciseName) \(count)"
        }
    }

    enum SaveOutcome: Equatable {
        case saved
        // No connection: saved later from the queue.
        case queued
        case failed(message: String)
    }

    /// What one Save of all trainings ended with, once every form answered.
    enum SaveAllResult: Equatable {
        // Every training is saved or kept on the device.
        case saved(anyQueued: Bool)
        // These trainings were not saved (in the session's order); the others were.
        case failed([UUID])
    }

    private(set) var participants: [Participant]
    private(set) var activeId: UUID
    // The shared start: when the first training's name was written.
    private(set) var startedAt: Date?
    // Forms still saving during a Save of all trainings, and their answers.
    private(set) var pendingSaves: Set<UUID> = []
    private(set) var outcomes: [UUID: SaveOutcome] = [:]

    init(first: Participant, startedAt: Date? = nil) {
        participants = [first]
        activeId = first.id
        self.startedAt = startedAt
    }

    var active: Participant {
        participants.first { $0.id == activeId } ?? participants[0]
    }

    /// More than one client: the form shows the shared time and the switcher.
    var isShared: Bool {
        participants.count > 1
    }

    var isSaving: Bool {
        !pendingSaves.isEmpty
    }

    func contains(clientId: UUID) -> Bool {
        participants.contains { $0.clientId == clientId }
    }

    func participant(_ id: UUID) -> Participant? {
        participants.first { $0.id == id }
    }

    // MARK: - Clients

    /// Adds a client's training and shows it; false when the client is in already.
    @discardableResult
    mutating func add(_ participant: Participant) -> Bool {
        guard !contains(clientId: participant.clientId), !isSaving else { return false }
        participants.append(participant)
        activeId = participant.id
        return true
    }

    /// Only with another client left, and not while saving.
    func canRemove(_ id: UUID) -> Bool {
        isShared && !isSaving && participant(id) != nil
    }

    /// Asked first when something of the training would be lost.
    func needsConfirmationToRemove(_ id: UUID) -> Bool {
        guard let participant = participant(id) else { return false }
        return participant.enteredSets > 0 || participant.isPersisted
    }

    /// Removes a client's training; the one next to it is shown if it was.
    @discardableResult
    mutating func remove(_ id: UUID) -> Participant? {
        guard canRemove(id), let index = participants.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = participants.remove(at: index)
        outcomes[id] = nil
        if activeId == id {
            activeId = participants[min(index, participants.count - 1)].id
        }
        return removed
    }

    mutating func select(_ id: UUID) {
        guard participant(id) != nil else { return }
        activeId = id
    }

    mutating func update(_ id: UUID, _ change: (inout Participant) -> Void) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }
        change(&participants[index])
    }

    // MARK: - Shared time

    /// The first name written starts the time of all trainings; later ones
    /// (and clients added later) keep it. True when it started now.
    @discardableResult
    mutating func start(at date: Date) -> Bool {
        guard startedAt == nil else { return false }
        startedAt = date
        return true
    }

    // MARK: - Texts

    /// Segment of the switcher: "Ana · Upper body", "Ana" before the name is written.
    func segmentLabel(_ participant: Participant) -> String {
        let name = participant.trainingName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? participant.shortName : "\(participant.shortName) · \(name)"
    }

    /// "Ana · Marko" in the header.
    var headerNames: String {
        participants.map(\.shortName).joined(separator: " · ")
    }

    /// Clients on the coach's Live Activity: the full name of one, "Ana, Marko" of more.
    var activityClientNames: String {
        isShared ? participants.map(\.shortName).joined(separator: ", ") : participants[0].fullName
    }

    /// The training the Live Activity is linked to: the first client's.
    var leader: Participant {
        participants[0]
    }

    /// Clients other than the shown one, for the lines under its exercises.
    var others: [Participant] {
        participants.filter { $0.id != activeId }
    }

    var canSave: Bool {
        !isSaving && participants.allSatisfy(\.isValid)
    }

    var hasChanges: Bool {
        participants.contains(where: \.hasChanges)
    }

    var isPersisted: Bool {
        participants.contains(where: \.isPersisted)
    }

    // MARK: - Save all

    /// Every training is saved (again), also those saved by an earlier try,
    /// so changes made after it aren't lost. Returns the forms that save now.
    mutating func beginSaveAll() -> [UUID] {
        guard canSave else { return [] }
        outcomes = [:]
        pendingSaves = Set(participants.map(\.id))
        return participants.map(\.id)
    }

    /// A form's answer; the result once every form answered, nil before.
    mutating func record(_ outcome: SaveOutcome, for id: UUID) -> SaveAllResult? {
        guard pendingSaves.remove(id) != nil else { return nil }
        outcomes[id] = outcome
        guard pendingSaves.isEmpty else { return nil }

        let failed = participants.map(\.id).filter {
            if case .failed = outcomes[$0] { return true }
            return false
        }
        if !failed.isEmpty {
            return .failed(failed)
        }
        return .saved(anyQueued: outcomes.values.contains(.queued))
    }

    /// The server's message of a training that was not saved.
    func failureMessage(_ id: UUID) -> String? {
        if case .failed(let message) = outcomes[id] { return message }
        return nil
    }
}

/// Trainings started together in a session, so ending one from the Live
/// Activity or the reminder ends all of them. Kept on the device for a day.
enum TrainingSessionRegistry {
    private static let storageKey = "trainingSessions"
    private static let keptFor: TimeInterval = 24 * 60 * 60

    private struct Group: Codable {
        var trainingIds: [UUID]
        var updatedAt: Date
    }

    /// A training of the session was created (and started).
    static func add(_ trainingId: UUID, toSession sessionKey: UUID, defaults: UserDefaults = .standard,
                    now: Date = .now) {
        var groups = read(defaults).filter { now.timeIntervalSince($0.value.updatedAt) < keptFor }
        var group = groups[sessionKey.uuidString] ?? Group(trainingIds: [], updatedAt: now)
        if !group.trainingIds.contains(trainingId) {
            group.trainingIds.append(trainingId)
        }
        group.updatedAt = now
        groups[sessionKey.uuidString] = group
        write(groups, defaults)
    }

    /// The other trainings of the session the training belongs to (none for a training on its own).
    static func siblings(of trainingId: UUID, defaults: UserDefaults = .standard) -> [UUID] {
        guard let group = read(defaults).values.first(where: { $0.trainingIds.contains(trainingId) }) else {
            return []
        }
        return group.trainingIds.filter { $0 != trainingId }
    }

    private static func read(_ defaults: UserDefaults) -> [String: Group] {
        guard let data = defaults.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Group].self, from: data)) ?? [:]
    }

    private static func write(_ groups: [String: Group], _ defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(groups), forKey: storageKey)
    }
}
