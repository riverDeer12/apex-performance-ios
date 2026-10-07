//
//  AppStoreScreenshotTests.swift
//  ApexPerformanceUITests
//

import XCTest

/// Takes App Store screenshots of the main coach and client screens.
/// Screenshots are always taken in English.
///
/// Needs a coach and a client account on the server the build uses
/// (Debug uses the test API). Credentials are read from the scheme's
/// Test environment variables so they are never committed:
///   APEX_SCREENSHOT_COACH_USERNAME, APEX_SCREENSHOT_COACH_PASSWORD
///   APEX_SCREENSHOT_CLIENT_USERNAME, APEX_SCREENSHOT_CLIENT_PASSWORD
/// A test whose credentials are missing is skipped.
///
/// PNGs are saved to ~/Desktop/ApexScreenshots/<device>/ on the Mac
/// and are also attached to the test report.
final class AppStoreScreenshotTests: XCTestCase {

    private var app: XCUIApplication!
    private var outputDirectory: URL?
    private var screenshotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            // Overrides a language picked earlier in the app's language switcher.
            "-appLanguage", "en",
            // Start logged out, every test logs in with its own account.
            "-uiTestResetLogin"
        ]

        // Simulator processes can write to the Mac's file system.
        let environment = ProcessInfo.processInfo.environment
        if let hostHome = environment["SIMULATOR_HOST_HOME"] {
            let device = environment["SIMULATOR_DEVICE_NAME"] ?? "Simulator"
            let directory = URL(fileURLWithPath: hostHome)
                .appendingPathComponent("Desktop/ApexScreenshots")
                .appendingPathComponent(device)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            outputDirectory = directory
        }
    }

    func testCoachScreenshots() throws {
        app.launch()
        try logIn(role: "COACH")

        let tabs = try tabButtons()
        let tabCount = tabs.count

        // Coach tabs: appointments, appointment requests (with permission),
        // workouts, clients, profile. Tabs have no titles, so they are
        // found by position from the end.
        XCTAssertGreaterThanOrEqual(tabCount, 4, "Expected coach tabs")

        // Appointments calendar with requests above it.
        tabs.element(boundBy: 0).tap()
        waitForContent()
        takeScreenshot("coach", "appointments")

        if tabCount >= 5 {
            tabs.element(boundBy: 1).tap()
            waitForContent()
            takeScreenshot("coach", "appointment-requests")
        }

        // Workouts library.
        tabs.element(boundBy: tabCount - 3).tap()
        waitForContent()
        takeScreenshot("coach", "workouts")

        // Clients list.
        tabs.element(boundBy: tabCount - 2).tap()
        let clientRow = app.buttons["client-row"].firstMatch
        XCTAssertTrue(clientRow.waitForExistence(timeout: 15), "Coach has no clients to show")
        waitForContent()
        takeScreenshot("coach", "clients")

        // Client details: weight chart, body measurements and FMS.
        clientRow.tap()
        waitForContent()
        takeScreenshot("coach", "client-details")

        app.swipeUp()
        waitForContent(seconds: 1)
        takeScreenshot("coach", "client-progress")

        app.swipeUp()
        waitForContent(seconds: 1)
        takeScreenshot("coach", "client-measurements-fms")

        // Profile.
        tabs.element(boundBy: tabCount - 1).tap()
        waitForContent()
        takeScreenshot("coach", "profile")
    }

    func testClientScreenshots() throws {
        app.launch()
        try logIn(role: "CLIENT")

        let tabs = try tabButtons()
        let tabCount = tabs.count

        // Client tabs: home, appointments (or requests without the
        // permission), trainings, profile.
        XCTAssertGreaterThanOrEqual(tabCount, 4, "Expected client tabs")

        // Home with the next appointment.
        tabs.element(boundBy: 0).tap()
        waitForContent()
        takeScreenshot("client", "home")

        // Progress: body mass and circumferences, then training charts.
        let progressTile = app.buttons["progress-tile"].firstMatch
        if progressTile.waitForExistence(timeout: 5) {
            progressTile.tap()
            waitForContent()
            takeScreenshot("client", "body-progress")

            app.swipeUp()
            waitForContent(seconds: 1)
            takeScreenshot("client", "body-circumferences")

            let trainingProgress = app.buttons["training-progress-row"].firstMatch
            if trainingProgress.waitForExistence(timeout: 5) {
                trainingProgress.tap()
                waitForContent()
                takeScreenshot("client", "training-progress")
            }
        }

        // Package with booked appointments.
        tabs.element(boundBy: 0).tap()
        let packageCard = app.buttons["package-card"].firstMatch
        if packageCard.waitForExistence(timeout: 5) {
            packageCard.tap()
            waitForContent()
            takeScreenshot("client", "package")
        }

        // Appointments with booking.
        tabs.element(boundBy: 1).tap()
        waitForContent()
        takeScreenshot("client", "appointments")

        // Sent requests with their status.
        let requestsButton = app.buttons["requests-button"].firstMatch
        if requestsButton.waitForExistence(timeout: 3) {
            requestsButton.tap()
            waitForContent()
            takeScreenshot("client", "requests")
            app.swipeDown(velocity: .fast)
            waitForContent(seconds: 1)
        }

        // Completed trainings and the details of the latest one.
        tabs.element(boundBy: tabCount - 2).tap()
        waitForContent()
        takeScreenshot("client", "trainings")

        let trainingRow = app.buttons["training-row"].firstMatch
        if trainingRow.waitForExistence(timeout: 5) {
            trainingRow.tap()
            waitForContent()
            takeScreenshot("client", "training-details")
        }

        // Profile with credits.
        tabs.element(boundBy: tabCount - 1).tap()
        waitForContent()
        takeScreenshot("client", "profile")
    }

    // MARK: - Helpers

    /// role is COACH or CLIENT, matching the environment variable names.
    private func logIn(role: String) throws {
        let environment = ProcessInfo.processInfo.environment
        guard let username = environment["APEX_SCREENSHOT_\(role)_USERNAME"],
              let password = environment["APEX_SCREENSHOT_\(role)_PASSWORD"],
              !username.isEmpty, !password.isEmpty else {
            throw XCTSkip("Set APEX_SCREENSHOT_\(role)_USERNAME and APEX_SCREENSHOT_\(role)_PASSWORD in the scheme's Test environment variables.")
        }

        let usernameField = app.textFields["login-username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Login screen not shown")
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["login-password"]
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["login-button"].tap()
    }

    private func tabButtons() throws -> XCUIElementQuery {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar not shown, is the login correct?")
        return tabBar.buttons
    }

    /// Gives the API time to answer and images time to load.
    private func waitForContent(seconds: TimeInterval = 3) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func takeScreenshot(_ role: String, _ name: String) {
        screenshotIndex += 1
        let fileName = String(format: "%@-%02d-%@", role, screenshotIndex, name)
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)

        if let outputDirectory {
            try? screenshot.pngRepresentation
                .write(to: outputDirectory.appendingPathComponent("\(fileName).png"))
        }
    }
}
