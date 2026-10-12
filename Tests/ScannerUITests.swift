import XCTest
final class ScannerUITests: XCTestCase {
    func testSearchCanTypeClearAndRetype() {
        let app = XCUIApplication(); app.launch()
        let search = app.textFields["pokemonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        search.tap(); search.typeText("espeon")
        XCTAssertEqual(search.value as? String, "espeon")
        app.buttons["Clear search"].tap(); search.typeText("pikachu")
        XCTAssertEqual(search.value as? String, "pikachu")
    }
    // Seed Photos with the Espeon fixture using simctl addmedia before these tests.
    private func importEspeon(_ app: XCUIApplication) {
        let scan = app.buttons["SCAN POKÉMON"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        scan.tap(); app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.tap()
    }
    func testImportAutomaticallyLoadsConfidentMatch() {
        let app = XCUIApplication(); app.launch()
        importEspeon(app)
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 30), app.debugDescription)
    }
    func testImportAndCandidateLookup() {
        let app = XCUIApplication(); app.launchArguments = ["--confirm-scans"]; app.launch()
        importEspeon(app)
        let candidate = app.buttons["scanCandidate-196"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 30), app.debugDescription)
        candidate.tap()
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 20), app.debugDescription)
    }
}
