import XCTest
import StoreKitTest

final class TipUITests: XCTestCase {
    func testDailyPromptDismissalManualAccessAndRelaunch() throws { try checkPrompt(accessibility: false) }
    func testAccessibleDismissal() throws { try checkPrompt(accessibility: true) }
    private func checkPrompt(accessibility: Bool) throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalTips", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url); session.disableDialogs = true; session.clearTransactions()
        defer { session.resetToDefaultState() }
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["--test-tips", "--reset-tip-state"]
        if accessibility { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 3) { cover.tap() }
        let dismiss = app.buttons["tipDismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 20))
        XCTAssertTrue(dismiss.isHittable)
        dismiss.tap()
        XCTAssertTrue(app.textFields["pokemonSearch"].isHittable)
        if accessibility { return }
        app.buttons["detailTab-info"].tap()
        let read = app.buttons["entryRead"]
        XCTAssertTrue(read.waitForExistence(timeout: 15)); read.tap()
        let lens = app.buttons["scannerLens"]
        let speaking = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 'Speaking'"), object: lens)
        XCTAssertEqual(XCTWaiter.wait(for: [speaking], timeout: 20), .completed)
        let manual = app.buttons["manualTip"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5)); manual.tap()
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5)); dismiss.tap()
        XCTAssertEqual(read.label, "Read")
        XCTAssertEqual(lens.value as? String, "Idle", "Dismissing support must not restart narration")
        app.terminate(); app.launchArguments = ["--test-tips"]; app.launch()
        if cover.waitForExistence(timeout: 3) { cover.tap() }
        XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 15))
        XCTAssertFalse(dismiss.exists, "Relaunching or unfolding cannot repeat today's attempt")
    }
}
