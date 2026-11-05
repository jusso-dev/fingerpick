import XCTest

/// App Store screenshots (#26). Skipped in normal CI; the Screenshots workflow sets
/// TEST_RUNNER_FINGERPICK_SCREENSHOTS=1 and exports the attachments as PNGs.
@MainActor
final class AppStoreScreenshots: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FINGERPICK_SCREENSHOTS"] == "1", "Screenshots run on demand")
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest", "-uitest-reset", "-uitest-seed", "11", "-hasSeenFirstRunHint", "YES", "-uitest-light",
        ] + arguments
        app.launch()
        return app
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addFingers(_ app: XCUIApplication, _ count: Int) {
        for _ in 0..<count { app.buttons["uitest.addFinger"].tap() }
    }

    func testWaitingScreen() {
        save(launch(), "1-waiting")
    }

    func testCountdown() {
        let app = launch(["-countdownSeconds", "5"])
        addFingers(app, 5)
        sleep(2)
        save(app, "2-countdown")
    }

    func testWinnerReveal() {
        let app = launch(["-countdownSeconds", "1"])
        addFingers(app, 5)
        XCTAssertTrue(app.staticTexts["result"].waitForExistence(timeout: 10))
        sleep(1)
        save(app, "3-winner")
    }

    func testTeams() {
        let app = launch(["-countdownSeconds", "1", "-mode", "teams", "-teamCount", "2"])
        addFingers(app, 6)
        XCTAssertTrue(app.staticTexts["result"].waitForExistence(timeout: 10))
        sleep(1)
        save(app, "4-teams")
    }

    func testTurnOrder() {
        let app = launch(["-countdownSeconds", "1", "-mode", "order"])
        addFingers(app, 5)
        XCTAssertTrue(app.staticTexts["result"].waitForExistence(timeout: 10))
        sleep(3)
        save(app, "5-order")
    }
}
