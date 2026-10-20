//
//  AppStoreScreenshotTests.swift
//  ApexPerformanceUITests
//

import XCTest

/// Takes App Store screenshots of the main coach and client screens.
/// Screenshots are always taken in English.
///
/// By default the app runs with invented demo data (DemoAPI, Debug builds
/// only), so no real people are shown. With APEX_SCREENSHOT_USE_SERVER=1
/// it uses a coach and a client account on the server the build uses
/// (Debug uses the test API), read from the scheme's Test environment
/// variables so they are never committed:
///   APEX_SCREENSHOT_COACH_USERNAME, APEX_SCREENSHOT_COACH_PASSWORD
///   APEX_SCREENSHOT_CLIENT_USERNAME, APEX_SCREENSHOT_CLIENT_PASSWORD
/// A test whose credentials are missing is then skipped.
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
        if usesDemoData {
            app.launchArguments.append("-demoData")
        }

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

        try waitForTabs()
        XCTAssertTrue(tab("Clients").exists, "Not a coach account (no Clients tab)")

        // Appointments calendar with requests above it.
        if tab("Appointments").exists {
            tab("Appointments").tap()
            waitForContent()
            takeScreenshot("coach", "appointments")
        }

        if tab("Requests").exists {
            tab("Requests").tap()
            waitForContent()
            takeScreenshot("coach", "appointment-requests")
        }

        // Workouts library.
        tab("Workouts").tap()
        waitForContent()
        takeScreenshot("coach", "workouts")

        // A workout with the muscles it works.
        let workoutRow = app.buttons["workout-row"].firstMatch
        if workoutRow.waitForExistence(timeout: 5) {
            workoutRow.tap()
            waitForContent()
            scrollTo(app.otherElements["muscle-map-card"].firstMatch)
            takeScreenshot("coach", "workout-muscles")
            goBack()
        }

        // Chat with a client: pictures and shared workouts.
        openChat(role: "coach")

        // Clients list.
        tab("Clients").tap()
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
        tab("Profile").tap()
        waitForContent()
        takeScreenshot("coach", "profile")
    }

    func testClientScreenshots() throws {
        app.launch()
        try logIn(role: "CLIENT")

        try waitForTabs()
        XCTAssertTrue(tab("Home").exists, "Not a client account (no Home tab)")

        // A changed goal and plan is shown over home once.
        waitForContent()
        if app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Got it")).firstMatch.exists {
            dismissSheet()
        }

        // Home with the next appointment.
        tab("Home").tap()
        waitForContent()
        takeScreenshot("client", "home")

        // Notifications behind the bell.
        let bell = app.buttons["notifications-bell"].firstMatch
        if bell.waitForExistence(timeout: 5) {
            bell.tap()
            waitForContent()
            takeScreenshot("client", "notifications")
            dismissSheet()
        }

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
        tab("Home").tap()
        let packageCard = app.buttons["package-card"].firstMatch
        if packageCard.waitForExistence(timeout: 5) {
            packageCard.tap()
            waitForContent()
            takeScreenshot("client", "package")
        }

        // Appointments with booking (requests without the permission).
        (tab("Appointments").exists ? tab("Appointments") : tab("Requests")).tap()
        waitForContent()
        takeScreenshot("client", "appointments")

        // Sent requests with their status.
        let requestsButton = app.buttons["requests-button"].firstMatch
        if requestsButton.waitForExistence(timeout: 3) {
            requestsButton.tap()
            waitForContent()
            takeScreenshot("client", "requests")
            dismissSheet()
        }

        // Completed trainings and the details of the latest one.
        tab("Trainings").tap()
        waitForContent()
        takeScreenshot("client", "trainings")

        let trainingRow = app.buttons["training-row"].firstMatch
        if trainingRow.waitForExistence(timeout: 5) {
            trainingRow.tap()
            waitForContent()
            takeScreenshot("client", "training-details")

            // An exercise of the training opens its workout and muscles.
            let exercise = app.buttons["exercise-link"].firstMatch
            if exercise.waitForExistence(timeout: 5) {
                exercise.tap()
                waitForContent()
                takeScreenshot("client", "workout")
                scrollTo(app.otherElements["muscle-map-card"].firstMatch)
                takeScreenshot("client", "workout-muscles")
                goBack()
            }
            goBack()
        }

        // Chat with the coach: pictures and shared workouts.
        openChat(role: "client")

        // Profile with credits.
        tab("Profile").tap()
        waitForContent()
        takeScreenshot("client", "profile")
    }

    // MARK: - Helpers

    /// role is COACH or CLIENT, matching the environment variable names.
    private var usesDemoData: Bool {
        ProcessInfo.processInfo.environment["APEX_SCREENSHOT_USE_SERVER"] != "1"
    }

    private func logIn(role: String) throws {
        let username: String
        let password: String
        if usesDemoData {
            // DemoAPI picks the coach or the client by the username.
            username = "demo.\(role.lowercased())"
            password = "demo"
        } else {
            let environment = ProcessInfo.processInfo.environment
            guard let serverUsername = environment["APEX_SCREENSHOT_\(role)_USERNAME"],
                  let serverPassword = environment["APEX_SCREENSHOT_\(role)_PASSWORD"],
                  !serverUsername.isEmpty, !serverPassword.isEmpty else {
                throw XCTSkip("Set APEX_SCREENSHOT_\(role)_USERNAME and APEX_SCREENSHOT_\(role)_PASSWORD in the scheme's Test environment variables.")
            }
            username = serverUsername
            password = serverPassword
        }

        allowSystemAlerts()
        let usernameField = app.textFields["login-username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Login screen not shown")
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["login-password"]
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["login-button"].tap()
        allowSystemAlerts()
    }

    /// Answers the notification permission alert, which covers the app.
    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) { button.tap() }
        }
    }

    /// Opens the first conversation from the chat button and closes the chat after.
    private func openChat(role: String) {
        let chatButton = app.buttons["chat-button"].firstMatch
        guard chatButton.waitForExistence(timeout: 5) else { return }
        chatButton.tap()
        let row = app.buttons["chat-row"].firstMatch
        if row.waitForExistence(timeout: 10) {
            row.tap()
            // Pictures load after the messages.
            waitForContent(seconds: 5)
            takeScreenshot(role, "chat")
            goBack()
        }
        let close = app.buttons["chat-close"].firstMatch
        if close.waitForExistence(timeout: 3) {
            close.tap()
        } else {
            dismissSheet()
        }
        waitForContent(seconds: 1)
    }

    /// Scrolls up until the element is on screen, a few times at most.
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { break }
            app.swipeUp()
        }
        // The whole card on screen, not just its top above the tab bar.
        let screenHeight = app.windows.firstMatch.frame.height
        if element.exists && element.frame.maxY > screenHeight - 120 {
            app.swipeUp(velocity: .slow)
        }
        waitForContent(seconds: 1)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        waitForContent(seconds: 1)
    }

    /// Closes the sheet on top: with its button when it has one, otherwise
    /// by tapping beside it (iPad) or dragging its grabber down (iPhone).
    private func dismissSheet() {
        for title in ["Got it", "Close", "Done"] {
            let button = app.buttons.matching(NSPredicate(format: "label ==[c] %@", title)).firstMatch
            if button.exists && button.isHittable {
                button.tap()
                waitForContent(seconds: 1)
                return
            }
        }
        if app.windows.firstMatch.frame.width > 700 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.065))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        waitForContent(seconds: 1)
    }

    /// Tab by its English title. iPhones show the tabs at the bottom,
    /// iPads at the top where they aren't a tab bar for the tests.
    private func tab(_ title: String) -> XCUIElement {
        let inTabBar = app.tabBars.buttons[title]
        if inTabBar.exists { return inTabBar }
        return app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func waitForTabs() throws {
        XCTAssertTrue(tab("Profile").waitForExistence(timeout: 20), "Tabs not shown, is the login correct?")
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
