import XCTest

final class SpeechUITests: XCTestCase {
    private func setAutoRead(_ enabled: Bool, in app: XCUIApplication) {
        let toggle = app.switches["autoRead"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != (enabled ? "1" : "0") {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
    }
    private func open(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 3) { cover.tap() }
        if app.descendants(matching: .any).matching(identifier: "duoCover").firstMatch.exists { throw XCTSkip("Unfold Duo before testing narration") }
        XCTAssertTrue(app.buttons["entryRead"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.buttons["entryRead"].label, "Read")
    }
    func testReadStopSettingsPersistenceCoverAndBackground() throws {
        let app = XCUIApplication(); try open(app)
        let read = app.buttons["entryRead"]
        XCTAssertTrue(read.isEnabled); read.tap()
        XCTAssertEqual(read.label, "Stop")
        read.tap(); XCTAssertEqual(read.label, "Read")
        app.buttons["audioSettings"].tap()
        let toggle = app.switches["autoRead"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        setAutoRead(false, in: app)
        app.buttons["audioSettingsDone"].tap()
        app.terminate(); try open(app)
        app.buttons["audioSettings"].tap()
        XCTAssertEqual(toggle.value as? String, "0")
        setAutoRead(true, in: app); app.buttons["audioSettingsDone"].tap()
        read.tap(); XCUIDevice.shared.press(.home)
        print("DexDuo state after Home: \(app.state.rawValue)")
        XCUIApplication(bundleIdentifier: "com.apple.Preferences").activate()
        XCTAssertTrue(app.state == .runningBackground || app.state == .runningBackgroundSuspended, "The app must actually leave the foreground before testing background cancellation")
        app.activate()
        XCTAssertTrue(read.waitForExistence(timeout: 5)); XCTAssertEqual(read.label, "Read")
        if app.buttons["phoneCoverButton"].exists {
            read.tap(); app.buttons["phoneCoverButton"].tap(); app.buttons["phoneCover"].tap()
            XCTAssertEqual(read.label, "Read")
        }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Info with robotic audio controls"; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testAutomaticSelectionAndScannerStop() throws {
        let app = XCUIApplication(); try open(app)
        app.buttons["audioSettings"].tap()
        setAutoRead(true, in: app)
        app.buttons["audioSettingsDone"].tap()
        let field = app.textFields["pokemonSearch"]
        field.tap(); field.typeText("gastly")
        let match = app.buttons["searchCandidate-gastly"]
        XCTAssertTrue(match.waitForExistence(timeout: 10)); match.tap()
        let stop = app.buttons["entryRead"]
        let speaking = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Stop'"), object: stop)
        XCTAssertEqual(XCTWaiter.wait(for: [speaking], timeout: 15), .completed)
        if app.buttons["phoneScan"].exists { app.buttons["phoneScan"].tap() }
        else { app.buttons["Open Pokémon scanner"].tap() }
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 5)); XCTAssertEqual(stop.label, "Read")
    }
    func testAccessibilityAudioSettingsKeepsDoneReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .landscapeLeft; app.launch()
        if app.buttons["phoneCover"].waitForExistence(timeout: 3) { app.buttons["phoneCover"].tap() }
        if app.descendants(matching: .any).matching(identifier: "duoCover").firstMatch.exists { throw XCTSkip("Unfold Duo before checking settings") }
        let panels = app.segmentedControls["phonePanelPicker"]
        if panels.waitForExistence(timeout: 2) { panels.buttons["Details"].tap() }
        XCTAssertTrue(app.buttons["audioSettings"].waitForExistence(timeout: 10)); app.buttons["audioSettings"].tap()
        let done = app.buttons["audioSettingsDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); XCTAssertTrue(done.isHittable)
        XCTAssertTrue(app.frame.contains(done.frame)); done.tap()
        XCTAssertTrue(app.buttons["entryRead"].exists)
    }
}
