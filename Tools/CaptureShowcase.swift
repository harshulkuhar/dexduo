import XCTest

/// Loaded only by capture_showcase.py's temporary test project, never the app or normal test target.
final class CaptureShowcase: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private func capture(_ name: String) {
        print("DEXDUO_SHOWCASE:\(name)"); fflush(stdout)
        // Give the host's simctl screenshot command a short capture window.
        sleep(4)
    }
    private func ready(_ app: XCUIApplication) {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.activityIndicators.count == 0 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 30), .completed)
    }
    private func select(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["pokemonSearch"]; search.tap(); search.typeText(name)
        let candidate = app.buttons["searchCandidate-\(name)"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 15)); candidate.tap()
        XCTAssertTrue(app.staticTexts[name.uppercased()].waitForExistence(timeout: 30)); ready(app)
    }
    func testCaptureScenes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        // Temporary preference overrides suppress unrelated prompts/narration, not recognition results.
        app.launchArguments = ["--confirm-scans", "-DexDuoSupported", "YES", "-DexDuoAutoRead", "NO"]
        app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 3) { cover.tap() }
        XCTAssertTrue(app.buttons["entryRead"].waitForExistence(timeout: 30)); ready(app)
        capture("01-open")

        app.buttons["scannerLens"].tap()
        XCTAssertTrue(app.buttons["scanImport"].waitForExistence(timeout: 10)); app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30)); photo.tap()
        XCTAssertTrue(app.buttons["scanCandidate-196"].waitForExistence(timeout: 60)); ready(app)
        capture("02-recognition")
        app.buttons["Done"].tap()

        app.buttons["entryRead"].tap()
        let speaking = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Speaking'"), object: app.buttons["scannerLens"])
        XCTAssertEqual(XCTWaiter.wait(for: [speaking], timeout: 30), .completed)
        capture("03-speech")
        if app.buttons["entryRead"].label == "Stop" { app.buttons["entryRead"].tap() }

        select("kirlia", in: app); app.buttons["detailTab-evolution"].tap()
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30))
        let gallade = app.buttons["evolutionNode-gallade"]
        for _ in 0..<16 {
            if gallade.exists && scroll.frame.insetBy(dx: -2, dy: -2).contains(gallade.frame) { break }
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.75))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(gallade.isHittable); ready(app)
        capture("04-evolution")

        select("gyarados", in: app); app.buttons["detailTab-types"].tap()
        let electric = app.descendants(matching: .any).matching(identifier: "typeMatchup-electric").firstMatch
        XCTAssertTrue(electric.waitForExistence(timeout: 15)); XCTAssertTrue(electric.label.contains("four times damage"))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "typeMatchup-ground").firstMatch.label.contains("immune"))
        ready(app); capture("05-matchup")

        app.buttons["detailTab-info"].tap(); select("pikachu", in: app)
        if app.buttons["phoneCoverButton"].exists { app.buttons["phoneCoverButton"].tap(); capture("06-cover") }
        else { ready(app); capture("06-interior") }
    }
}
