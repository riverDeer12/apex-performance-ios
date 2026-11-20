//
//  LiveActivityLogicTests.swift
//  ApexPerformanceTests
//

import XCTest
@testable import ApexPerformance

/// Training Live Activities: which of two activities of a training stays,
/// when a training list may end one, and which are started again.
final class LiveActivityLogicTests: XCTestCase {

    private typealias Shown = LiveActivityLogic.Shown
    private typealias Run = LiveActivityLogic.LocalRun

    private let training = "T1"
    private let coach = "C1"

    private func run(_ id: String = "T1", startedAt: Date = .now.addingTimeInterval(-600),
                     userId: String? = "C1", dismissed: Bool = false) -> Run {
        var run = Run(trainingId: id, startedAt: startedAt, name: "Legs", clientName: "Ana", userId: userId)
        run.dismissedByUser = dismissed
        return run
    }

    // MARK: - Duplicates

    func testTheActivityStartedByTheAppStaysWhenAPushStartCrossesIt() {
        let pushed = Shown(id: "push", trainingId: training, startedByApp: false)
        let local = Shown(id: "local", trainingId: training, startedByApp: true)

        XCTAssertEqual(LiveActivityLogic.survivors([pushed, local]), [training: "local"])
        XCTAssertEqual(LiveActivityLogic.duplicates([pushed, local]), ["push"])
        // Whatever order iOS lists them in.
        XCTAssertEqual(LiveActivityLogic.duplicates([local, pushed]), ["push"])
    }

    func testOnlyOneOfTwoIsEndedNeverBoth() {
        let first = Shown(id: "a", trainingId: training, startedByApp: true)
        let second = Shown(id: "b", trainingId: training, startedByApp: true)

        XCTAssertEqual(LiveActivityLogic.duplicates([first, second]), ["b"])
        let pushedFirst = Shown(id: "p1", trainingId: training, startedByApp: false)
        let pushedSecond = Shown(id: "p2", trainingId: training, startedByApp: false)
        XCTAssertEqual(LiveActivityLogic.duplicates([pushedFirst, pushedSecond]), ["p2"])
    }

    func testDraftsAndOtherTrainingsAreNotDuplicates() {
        let draft = Shown(id: "draft", trainingId: nil, startedByApp: true)
        let pushed = Shown(id: "push", trainingId: training, startedByApp: false)
        let other = Shown(id: "other", trainingId: "T2", startedByApp: true)

        XCTAssertEqual(LiveActivityLogic.duplicates([draft, pushed, other]), [])
        XCTAssertEqual(LiveActivityLogic.survivors([draft, pushed, other]), [training: "push", "T2": "other"])
    }

    // MARK: - Sync with the server

    func testAListAskedForBeforeTheTrainingStartedHereDoesNotEndIt() {
        let fetchedAt = Date.now
        // Locking the phone saved and started the training after the list was asked for.
        XCTAssertFalse(LiveActivityLogic.mayEnd(fetchedAt: fetchedAt, lastLocalChange: fetchedAt.addingTimeInterval(1)))
    }

    func testANewerListEndsIt() {
        let fetchedAt = Date.now
        XCTAssertTrue(LiveActivityLogic.mayEnd(fetchedAt: fetchedAt, lastLocalChange: fetchedAt.addingTimeInterval(-1)))
        XCTAssertTrue(LiveActivityLogic.mayEnd(fetchedAt: fetchedAt, lastLocalChange: nil))
    }

    // MARK: - Reconcile

    func testARunningTrainingWithoutActivityIsStartedAgainInTheForeground() {
        let started = LiveActivityLogic.toStart(runs: [run()], runningOnServer: [training], shown: [],
                                                userId: coach, isForeground: true, activitiesEnabled: true)
        XCTAssertEqual(started.map(\.trainingId), [training])
    }

    func testNothingIsStartedInTheBackgroundOrWithActivitiesOff() {
        XCTAssertTrue(LiveActivityLogic.toStart(runs: [run()], runningOnServer: [training], shown: [],
                                                userId: coach, isForeground: false, activitiesEnabled: true).isEmpty)
        XCTAssertTrue(LiveActivityLogic.toStart(runs: [run()], runningOnServer: [training], shown: [],
                                                userId: coach, isForeground: true, activitiesEnabled: false).isEmpty)
    }

    func testAShownTrainingIsNotStartedAgain() {
        // Also when the shown one was started by push.
        let pushed = Shown(id: "push", trainingId: training, startedByApp: false)
        XCTAssertTrue(LiveActivityLogic.toStart(runs: [run()], runningOnServer: [training], shown: [pushed],
                                                userId: coach, isForeground: true, activitiesEnabled: true).isEmpty)
    }

    func testOnlyTrainingsTheServerSaysAreRunning() {
        XCTAssertTrue(LiveActivityLogic.toStart(runs: [run()], runningOnServer: [], shown: [],
                                                userId: coach, isForeground: true, activitiesEnabled: true).isEmpty)
    }

    func testNotAnotherCoachsNorADismissedNorAnOutdatedTraining() {
        let runs = [run("A", userId: "C2"), run("B", dismissed: true),
                    run("C", startedAt: .now.addingTimeInterval(-13 * 60 * 60)), run("D")]
        let started = LiveActivityLogic.toStart(runs: runs, runningOnServer: ["A", "B", "C", "D"], shown: [],
                                                userId: coach, isForeground: true, activitiesEnabled: true)
        XCTAssertEqual(started.map(\.trainingId), ["D"])
    }

    func testTheDraftOfARunningFormIsStartedAgainWhenItWentAway() {
        XCTAssertTrue(LiveActivityLogic.draftNeedsRestart(key: "k", isRunning: true, shownKeys: [],
                                                          isForeground: true, activitiesEnabled: true))
        // Never started (activities were off and are on now).
        XCTAssertTrue(LiveActivityLogic.draftNeedsRestart(key: nil, isRunning: true, shownKeys: [],
                                                          isForeground: true, activitiesEnabled: true))
    }

    func testTheDraftIsKeptWhenShownAndNotStartedInTheBackground() {
        XCTAssertFalse(LiveActivityLogic.draftNeedsRestart(key: "k", isRunning: true, shownKeys: ["k"],
                                                           isForeground: true, activitiesEnabled: true))
        XCTAssertFalse(LiveActivityLogic.draftNeedsRestart(key: "k", isRunning: true, shownKeys: [],
                                                           isForeground: false, activitiesEnabled: true))
        XCTAssertFalse(LiveActivityLogic.draftNeedsRestart(key: "k", isRunning: false, shownKeys: [],
                                                           isForeground: true, activitiesEnabled: true))
    }

    func testLocalRunsSurviveTheAppBeingClosed() throws {
        let runs = [run(), run("T2", dismissed: true)]
        let decoded = try JSONDecoder().decode([Run].self, from: JSONEncoder().encode(runs))
        XCTAssertEqual(decoded, runs)
    }
}
