import XCTest

final class SpeechUITests: XCTestCase {
    private func waitForLens(_ app: XCUIApplication, value: String) {
        let lens = app.buttons["scannerLens"]
        XCTAssertTrue(lens.waitForExistence(timeout: 5))
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: lens)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 20), .completed, "Lens must reflect actual playback: \(value)")
    }
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
        read.tap(); waitForLens(app, value: "Speaking"); XCUIDevice.shared.press(.home)
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate(); settings.launch()
        let background = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.state == .runningBackground || app.state == .runningBackgroundSuspended
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [background], timeout: 5), .completed,
                       "The app must actually leave the foreground before testing background cancellation")
        app.activate()
        XCTAssertTrue(read.waitForExistence(timeout: 5)); XCTAssertEqual(read.label, "Read"); waitForLens(app, value: "Idle")
        if app.buttons["phoneCoverButton"].exists {
            read.tap(); waitForLens(app, value: "Speaking"); app.buttons["phoneCoverButton"].tap(); app.buttons["phoneCover"].tap()
            XCTAssertEqual(read.label, "Read"); waitForLens(app, value: "Idle")
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
        waitForLens(app, value: "Speaking")
        XCTAssertEqual(stop.label, "Stop")
        app.buttons["scannerLens"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["Done"].tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 5)); XCTAssertEqual(stop.label, "Read"); waitForLens(app, value: "Idle")
    }
    func testSpeakingLensRetainsFrameAndScannerAction() throws {
        let app = XCUIApplication(); try open(app)
        let lens = app.buttons["scannerLens"], read = app.buttons["entryRead"]
        let phone = app.buttons["phoneCoverButton"].exists
        let orientations: [UIDeviceOrientation] = phone ? [.landscapeLeft, .landscapeRight] : [.landscapeLeft]
        for orientation in orientations {
            XCUIDevice.shared.orientation = orientation
            waitForLens(app, value: "Idle")
            let idleFrame = lens.frame
            XCTAssertGreaterThanOrEqual(idleFrame.width, 44); XCTAssertGreaterThanOrEqual(idleFrame.height, 44)
            let idle = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            idle.name = "Lens idle \(orientation.rawValue)"; idle.lifetime = .keepAlways; add(idle)
            print("DexDuo lens idle capture \(orientation.rawValue)")
            let unexpectedStart = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != 'Idle'"), object: lens)
            unexpectedStart.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [unexpectedStart], timeout: 1), .completed)
            read.tap(); waitForLens(app, value: "Speaking")
            XCTAssertEqual(lens.frame, idleFrame, "The glow must not move or resize the scanner control")
            print("DexDuo lens playback capture \(orientation.rawValue)")
            let speaking = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            speaking.name = "Lens actual playback \(orientation.rawValue)"; speaking.lifetime = .keepAlways; add(speaking)
            let unexpectedStop = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != 'Speaking'"), object: lens)
            unexpectedStop.isInverted = true
            XCTAssertEqual(XCTWaiter.wait(for: [unexpectedStop], timeout: 2), .completed, "Playback must remain active while observing the halo")
            read.tap(); waitForLens(app, value: "Idle")
            XCTAssertEqual(lens.frame, idleFrame)
        }
        read.tap(); waitForLens(app, value: "Speaking"); lens.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        waitForLens(app, value: "Idle"); XCTAssertEqual(read.label, "Read")
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
