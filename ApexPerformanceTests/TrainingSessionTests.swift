//
//  TrainingSessionTests.swift
//  ApexPerformanceTests
//

import XCTest
@testable import ApexPerformance

/// Trainings of clients training at the same time: switching between them,
/// the shared time and saving all of them.
final class TrainingSessionTests: XCTestCase {

    private let ana = TrainingSession.Participant(clientId: UUID(), firstName: "Ana", lastName: "Anić")
    private let marko = TrainingSession.Participant(clientId: UUID(), firstName: "Marko", lastName: "Marić")
    private let ivan = TrainingSession.Participant(clientId: UUID(), firstName: " Ivan ", lastName: "Ivić")

    private func session(_ participants: TrainingSession.Participant...) -> TrainingSession {
        var session = TrainingSession(first: participants[0])
        for participant in participants.dropFirst() {
            session.add(participant)
        }
        return session
    }

    // MARK: - Clients and switching

    func testOneClientIsNotShared() {
        let session = session(ana)
        XCTAssertFalse(session.isShared)
        XCTAssertEqual(session.active.id, ana.id)
        XCTAssertEqual(session.activityClientNames, "Ana Anić")
        XCTAssertFalse(session.canRemove(ana.id))
    }

    func testAddedClientIsShownAndSharesTheSession() {
        var session = session(ana)
        XCTAssertTrue(session.add(marko))
        XCTAssertTrue(session.isShared)
        XCTAssertEqual(session.activeId, marko.id)
        XCTAssertEqual(session.headerNames, "Ana · Marko")
        XCTAssertEqual(session.activityClientNames, "Ana, Marko")
        XCTAssertEqual(session.leader.id, ana.id)
    }

    func testSameClientIsNotAddedTwice() {
        var session = session(ana, marko)
        let again = TrainingSession.Participant(clientId: ana.clientId, firstName: "Ana", lastName: "Anić")
        XCTAssertFalse(session.add(again))
        XCTAssertEqual(session.participants.count, 2)
    }

    func testSwitchingKeepsEveryTraining() {
        var session = session(ana, marko)
        session.update(ana.id) { $0.trainingName = "Gornji dio"; $0.enteredSets = 3 }
        session.update(marko.id) { $0.trainingName = "Noge" }

        session.select(ana.id)
        XCTAssertEqual(session.active.trainingName, "Gornji dio")
        session.select(marko.id)
        XCTAssertEqual(session.active.trainingName, "Noge")
        session.select(ana.id)
        XCTAssertEqual(session.active.enteredSets, 3)
        XCTAssertEqual(session.others.map(\.id), [marko.id])

        // Unknown ids change nothing.
        session.select(UUID())
        XCTAssertEqual(session.activeId, ana.id)
    }

    func testSegmentLabels() {
        var session = session(ana, ivan)
        XCTAssertEqual(session.segmentLabel(session.participants[0]), "Ana")
        session.update(ana.id) { $0.trainingName = "  Gornji dio " }
        XCTAssertEqual(session.segmentLabel(session.participants[0]), "Ana · Gornji dio")
        XCTAssertEqual(session.segmentLabel(session.participants[1]), "Ivan")

        let noFirstName = TrainingSession.Participant(clientId: UUID(), firstName: nil, lastName: "Horvat")
        XCTAssertEqual(noFirstName.shortName, "Horvat")
    }

    func testRemovingAClient() {
        var session = session(ana, marko, ivan)
        session.select(marko.id)
        XCTAssertFalse(session.needsConfirmationToRemove(marko.id))
        session.update(marko.id) { $0.enteredSets = 1 }
        XCTAssertTrue(session.needsConfirmationToRemove(marko.id))

        XCTAssertEqual(session.remove(marko.id)?.id, marko.id)
        // The one in its place is shown.
        XCTAssertEqual(session.activeId, ivan.id)
        XCTAssertEqual(session.remove(ivan.id)?.id, ivan.id)
        XCTAssertEqual(session.activeId, ana.id)
        // The last client stays.
        XCTAssertNil(session.remove(ana.id))
        XCTAssertFalse(session.isShared)
    }

    func testSavedTrainingNeedsConfirmationToRemove() {
        var session = session(ana, marko)
        session.update(marko.id) { $0.isQueued = true }
        XCTAssertTrue(session.needsConfirmationToRemove(marko.id))
        XCTAssertTrue(session.isPersisted)
    }

    // MARK: - Shared time

    func testFirstNameStartsTheSharedTime() {
        var session = session(ana)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(session.start(at: start))
        // Later names and clients keep it.
        XCTAssertFalse(session.start(at: start.addingTimeInterval(120)))
        session.add(marko)
        XCTAssertEqual(session.startedAt, start)
    }

    // MARK: - Save all

    private func validSession() -> TrainingSession {
        var session = session(ana, marko, ivan)
        for participant in session.participants {
            session.update(participant.id) { $0.isValid = true }
        }
        return session
    }

    func testSaveNeedsEveryTrainingComplete() {
        var session = validSession()
        session.update(marko.id) { $0.isValid = false }
        XCTAssertFalse(session.canSave)
        XCTAssertTrue(session.beginSaveAll().isEmpty)
    }

    func testAllSaved() {
        var session = validSession()
        XCTAssertEqual(session.beginSaveAll(), [ana.id, marko.id, ivan.id])
        XCTAssertTrue(session.isSaving)
        XCTAssertFalse(session.canSave)
        // Nothing can be added or removed while saving.
        XCTAssertFalse(session.canRemove(marko.id))

        XCTAssertNil(session.record(.saved, for: marko.id))
        XCTAssertNil(session.record(.saved, for: ana.id))
        XCTAssertEqual(session.record(.saved, for: ivan.id), .saved(anyQueued: false))
        XCTAssertFalse(session.isSaving)
    }

    func testQueuedCountsAsSaved() {
        var session = validSession()
        _ = session.beginSaveAll()
        _ = session.record(.saved, for: ana.id)
        _ = session.record(.queued, for: marko.id)
        XCTAssertEqual(session.record(.saved, for: ivan.id), .saved(anyQueued: true))
    }

    func testFailedOnesAreReportedTheOthersSaved() {
        var session = validSession()
        _ = session.beginSaveAll()
        _ = session.record(.failed(message: "Server error"), for: ivan.id)
        _ = session.record(.saved, for: ana.id)
        XCTAssertEqual(session.record(.failed(message: "No access"), for: marko.id), .failed([marko.id, ivan.id]))
        XCTAssertEqual(session.failureMessage(marko.id), "No access")
        XCTAssertNil(session.failureMessage(ana.id))

        // Retry saves everything again and forgets the earlier answers.
        XCTAssertEqual(session.beginSaveAll().count, 3)
        XCTAssertNil(session.failureMessage(marko.id))
    }

    func testAnswersOutsideASaveAreIgnored() {
        var session = validSession()
        XCTAssertNil(session.record(.saved, for: ana.id))
        _ = session.beginSaveAll()
        XCTAssertNil(session.record(.saved, for: ana.id))
        // The same form twice doesn't finish the save.
        XCTAssertNil(session.record(.saved, for: ana.id))
        XCTAssertTrue(session.isSaving)
    }

    // MARK: - Texts

    func testLastSetSummary() {
        let set = TrainingSession.SetActivity(at: .now, exerciseName: "Čučanj", enteredSets: 3, setCount: 4)
        XCTAssertEqual(set.summary, "Čučanj 3/4")
        XCTAssertEqual(TrainingSession.SetActivity(at: .now, exerciseName: "", enteredSets: 1, setCount: 2).summary, "1/2")
    }

    // MARK: - Ending all trainings of a session

    func testRegistryKnowsTheOtherTrainings() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "TrainingSessionTests"))
        defaults.removePersistentDomain(forName: "TrainingSessionTests")
        let session = UUID(), first = UUID(), second = UUID(), alone = UUID()

        TrainingSessionRegistry.add(first, toSession: session, defaults: defaults)
        TrainingSessionRegistry.add(second, toSession: session, defaults: defaults)
        TrainingSessionRegistry.add(second, toSession: session, defaults: defaults)
        TrainingSessionRegistry.add(alone, toSession: UUID(), defaults: defaults)

        XCTAssertEqual(TrainingSessionRegistry.siblings(of: first, defaults: defaults), [second])
        XCTAssertEqual(TrainingSessionRegistry.siblings(of: second, defaults: defaults), [first])
        XCTAssertEqual(TrainingSessionRegistry.siblings(of: alone, defaults: defaults), [])
        XCTAssertEqual(TrainingSessionRegistry.siblings(of: UUID(), defaults: defaults), [])

        // Sessions older than a day are forgotten.
        TrainingSessionRegistry.add(UUID(), toSession: UUID(), defaults: defaults, now: .now.addingTimeInterval(2 * 24 * 3600))
        XCTAssertEqual(TrainingSessionRegistry.siblings(of: first, defaults: defaults), [])
        defaults.removePersistentDomain(forName: "TrainingSessionTests")
    }
    // MARK: - Editing a saved session

    private func training(startedAt: Date? = nil, sessionId: UUID? = nil) -> Training {
        Training(id: UUID(), name: "Noge", date: .now, note: nil, isCompleted: false, completedAt: nil,
                 client: Training.Person(id: UUID(), firstName: "Marko", lastName: "Marić"), exercises: [],
                 startedAt: startedAt, sessionId: sessionId)
    }

    func testOnlyStaffEditSessionsOfMoreTrainings() {
        let two = [training(), training()]
        XCTAssertTrue(TrainingSession.opensAsSession(two, isStaff: true))
        XCTAssertFalse(TrainingSession.opensAsSession(two, isStaff: false))
        XCTAssertFalse(TrainingSession.opensAsSession([training()], isStaff: true))
        XCTAssertFalse(TrainingSession.opensAsSession([], isStaff: true))
    }

    func testSessionIsAskedForOnlyWhenThereCanBeOne() {
        XCTAssertFalse(TrainingSession.mayHaveSession(training()))
        XCTAssertTrue(TrainingSession.mayHaveSession(training(startedAt: .now)))
        XCTAssertTrue(TrainingSession.mayHaveSession(training(sessionId: UUID())))
    }

    func testEditedSessionShowsTheTappedClient() throws {
        var first = ana, second = marko
        first.existing = training(startedAt: .now)
        second.existing = training(startedAt: .now)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = try XCTUnwrap(TrainingSession(editing: [first, second], selected: marko.id, startedAt: start))
        XCTAssertEqual(session.activeId, marko.id)
        XCTAssertEqual(session.startedAt, start)
        // Saved trainings: something is lost only on purpose.
        XCTAssertTrue(session.needsConfirmationToRemove(ana.id))
        XCTAssertNil(TrainingSession(editing: [], selected: nil, startedAt: nil))
        XCTAssertEqual(TrainingSession(editing: [first, second], selected: UUID(), startedAt: nil)?.activeId, ana.id)
    }
}
