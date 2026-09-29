//
//  AppStoreScreenshotTests.swift
//  ApexPerformanceUITests
//

import XCTest

/// Takes App Store screenshots of the main coach screens.
///
/// Needs a coach account on the server the build uses (Debug uses the
/// test API). Credentials are read from the environment so they are
/// never committed:
///   APEX_SCREENSHOT_USERNAME, APEX_SCREENSHOT_PASSWORD
/// Optional: APEX_SCREENSHOT_LANGUAGE (hr, en or it; default hr).
///
/// PNGs are saved to ~/Desktop/ApexScreenshots/<language>/<device>/ on
/// the Mac and are also attached to the test report.
final class AppStoreScreenshotTests: XCTestCase {

    private var app: XCUIApplication!
    private var outputDirectory: URL?
    private var screenshotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = false

        let environment = ProcessInfo.processInfo.environment
        let language = environment["APEX_SCREENSHOT_LANGUAGE"] ?? "hr"

        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "en" ? "en_US" : "\(language)_\(language.uppercased())"
        ]

        // Simulator processes can write to the Mac's file system.
        if let hostHome = environment["SIMULATOR_HOST_HOME"] {
            let device = environment["SIMULATOR_DEVICE_NAME"] ?? "Simulator"
            let directory = URL(fileURLWithPath: hostHome)
                .appendingPathComponent("Desktop/ApexScreenshots")
                .appendingPathComponent(language)
                .appendingPathComponent(device)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            outputDirectory = directory
        }
    }

    func testCoachScreenshots() throws {
        app.launch()
        try logInIfNeeded()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar not shown, is the login correct?")

        // Coach tabs: appointments, appointment requests (with permission),
        // workouts, clients, profile. Tabs have no titles, so they are
        // found by position from the end.
        let tabs = tabBar.buttons
        let tabCount = tabs.count
        XCTAssertGreaterThanOrEqual(tabCount, 3, "Expected coach tabs")

        // 1. Appointments calendar (first tab, opened on launch).
        tabs.element(boundBy: 0).tap()
        waitForContent()
        takeScreenshot("appointments")

        // 2. Appointment requests, when the coach has that tab.
        if tabCount >= 5 {
            tabs.element(boundBy: 1).tap()
            waitForContent()
            takeScreenshot("appointment-requests")
        }

        // 3. Workouts library.
        tabs.element(boundBy: tabCount - 3).tap()
        waitForContent()
        takeScreenshot("workouts")

        // 4. Clients list.
        tabs.element(boundBy: tabCount - 2).tap()
        let clientRow = app.buttons["client-row"].firstMatch
        XCTAssertTrue(clientRow.waitForExistence(timeout: 15), "Coach has no clients to show")
        waitForContent()
        takeScreenshot("clients")

        // 5. Client details with body measurements and FMS.
        clientRow.tap()
        waitForContent()
        takeScreenshot("client-details")

        app.swipeUp()
        waitForContent(seconds: 1)
        takeScreenshot("client-measurements-fms")

        // 6. Profile.
        tabs.element(boundBy: tabCount - 1).tap()
        waitForContent()
        takeScreenshot("profile")
    }

    // MARK: - Helpers

    private func logInIfNeeded() throws {
        let usernameField = app.textFields["login-username"]
        guard usernameField.waitForExistence(timeout: 5) else {
            return // already logged in from an earlier run
        }

        let environment = ProcessInfo.processInfo.environment
        guard let username = environment["APEX_SCREENSHOT_USERNAME"],
              let password = environment["APEX_SCREENSHOT_PASSWORD"],
              !username.isEmpty, !password.isEmpty else {
            throw XCTSkip("Set APEX_SCREENSHOT_USERNAME and APEX_SCREENSHOT_PASSWORD in the scheme's Test environment variables.")
        }

        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["login-password"]
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["login-button"].tap()
    }

    /// Gives the API time to answer and images time to load.
    private func waitForContent(seconds: TimeInterval = 3) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func takeScreenshot(_ name: String) {
        screenshotIndex += 1
        let fileName = String(format: "%02d-%@", screenshotIndex, name)
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
