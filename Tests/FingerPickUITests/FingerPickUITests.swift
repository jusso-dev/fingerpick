import XCTest

/// Core flows through the real UI (#23). Fingers come from the `-uitest` touch injector, since
/// XCUITest can't put several fingers down at once.
@MainActor
final class FingerPickUITests: XCTestCase {
    override nonisolated func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitest-seed", "7", "-countdownSeconds", "1"]
            + (reset ? ["-uitest-reset"] : [])
            + extra
        app.launch()
        return app
    }

    private func skipHint(_ app: XCUIApplication) {
        let gotIt = app.buttons["hint.dismiss"]
        if gotIt.waitForExistence(timeout: 2) { gotIt.tap() }
    }

    private func playRound(_ app: XCUIApplication, fingers: Int) -> XCUIElement {
        for _ in 0..<fingers { app.buttons["uitest.addFinger"].tap() }
        let result = app.staticTexts["result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), "No result after the countdown")
        return result
    }

    func testLaunchShowsPromptAndSettingsButton() {
        let app = launch()
        skipHint(app)
        XCTAssertTrue(app.staticTexts["Everyone put a finger down"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.open"].exists)
        XCTAssertTrue(app.otherElements["playArea"].exists || app.descendants(matching: .any)["playArea"].exists)
    }

    func testFirstRunHintShowsOnce() {
        var app = launch()
        XCTAssertTrue(app.buttons["hint.dismiss"].waitForExistence(timeout: 5))
        app.buttons["hint.dismiss"].tap()
        XCTAssertFalse(app.buttons["hint.dismiss"].waitForExistence(timeout: 1))
        app.terminate()

        app = launch(reset: false)
        XCTAssertFalse(app.buttons["hint.dismiss"].waitForExistence(timeout: 2))
    }

    func testSimulatedRoundShowsResultAndResets() {
        let app = launch()
        skipHint(app)
        let result = playRound(app, fingers: 3)
        XCTAssertTrue(result.label.hasSuffix("picked"), result.label)
        XCTAssertFalse(app.buttons["settings.open"].exists, "Settings must hide during a round")

        app.buttons["uitest.liftAll"].tap()
        XCTAssertTrue(app.staticTexts["Everyone put a finger down"].waitForExistence(timeout: 5))
        XCTAssertFalse(result.exists)
    }

    func testRepeatedRoundsLeaveNoStaleResult() {
        let app = launch()
        skipHint(app)
        for _ in 0..<3 {
            _ = playRound(app, fingers: 2)
            app.buttons["uitest.liftAll"].tap()
            XCTAssertTrue(app.staticTexts["Everyone put a finger down"].waitForExistence(timeout: 5))
        }
    }

    func testOneFingerNeverPicks() {
        let app = launch()
        skipHint(app)
        app.buttons["uitest.addFinger"].tap()
        XCTAssertFalse(app.staticTexts["result"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Waiting for at least 2 fingers"].exists)
    }

    func testSettingsChangeEachSettingAndPersist() {
        var app = launch()
        skipHint(app)
        app.buttons["settings.open"].tap()

        app.buttons["settings.mode"].tap()
        app.buttons["Teams"].tap()
        let teams = app.steppers["settings.teams"]
        XCTAssertTrue(teams.waitForExistence(timeout: 3))
        teams.buttons.element(boundBy: 1).tap()
        app.steppers["settings.countdown"].buttons.element(boundBy: 1).tap()
        app.steppers["settings.minimumFingers"].buttons.element(boundBy: 1).tap()
        let haptics = app.switches["settings.haptics"]
        if !haptics.isHittable { app.swipeUp() }
        XCTAssertEqual(haptics.value as? String, "1")
        // Tap the control at the trailing edge; the toggle's centre is its label.
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(haptics.value as? String, "0")
        app.buttons["settings.done"].tap()
        app.terminate()

        // Relaunch without the countdown override so the saved value shows.
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-hasSeenFirstRunHint", "YES"]
        app.launch()
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.staticTexts["Teams: 3"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Minimum fingers: 3"].exists)
        XCTAssertEqual(app.switches["settings.haptics"].value as? String, "0")
    }

    func testTeamsAndOrderModesReveal() {
        var app = launch(extra: ["-mode", "teams"])
        skipHint(app)
        XCTAssertEqual(playRound(app, fingers: 4).label.hasPrefix("Team 1:"), true)
        app.terminate()

        app = launch(extra: ["-mode", "order"])
        skipHint(app)
        XCTAssertTrue(playRound(app, fingers: 3).label.hasPrefix("1: "))
    }

    func testSeveralWinnersNeedEnoughFingers() {
        let app = launch(extra: ["-mode", "winners", "-winnerCount", "2"])
        skipHint(app)
        app.buttons["uitest.addFinger"].tap()
        app.buttons["uitest.addFinger"].tap()
        XCTAssertTrue(app.staticTexts["Waiting for at least 3 fingers"].waitForExistence(timeout: 3))
        let result = playRound(app, fingers: 1)
        XCTAssertTrue(result.label.contains(" and "), result.label)
    }
}

/// Screenshots of the waiting screen and reveal in light, dark and an accessibility text size,
/// kept in the test results for review (#23).
@MainActor
final class FingerPickScreenshotTests: XCTestCase {
    private func capture(_ name: String, arguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest", "-uitest-reset", "-uitest-seed", "3", "-countdownSeconds", "1", "-hasSeenFirstRunHint", "YES",
        ] + arguments
        app.launch()
        attach(app, "\(name) waiting")
        for _ in 0..<4 { app.buttons["uitest.addFinger"].tap() }
        XCTAssertTrue(app.staticTexts["result"].waitForExistence(timeout: 10))
        sleep(1)
        attach(app, "\(name) reveal")
        app.terminate()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLightDarkAndAccessibilitySizes() {
        capture("Light", arguments: ["-uitest-light"])
        capture("Dark", arguments: ["-uitest-dark"])
        capture("Dark AX5", arguments: [
            "-uitest-dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
    }
}
