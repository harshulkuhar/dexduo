import XCTest
final class ScannerUITests: XCTestCase {
    private func launch(_ app: XCUIApplication) {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 4) { cover.tap() }
    }

    func testTypeGridAndBadgesFollowSelection() {
        let app = XCUIApplication(); launch(app)
        let search = app.textFields["pokemonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        app.buttons["detailTab-types"].tap()
        let electricity = app.descendants(matching: .any).matching(identifier: "typeMatchup-electric").firstMatch
        XCTAssertTrue(electricity.waitForExistence(timeout: 10))
        XCTAssertTrue(electricity.label.contains("half damage"))
        search.tap(); search.typeText("gyarados")
        let suggestion = app.buttons["searchCandidate-gyarados"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10)); suggestion.tap()
        XCTAssertTrue(app.staticTexts["GYARADOS"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pokemonType-water").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pokemonType-flying").firstMatch.exists)
        XCTAssertTrue(electricity.label.contains("four times damage"))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "typeMatchup-ground").firstMatch.label.contains("immune"))
        let types = "normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy".split(separator: " ")
        for type in types {
            let tile = app.descendants(matching: .any).matching(identifier: "typeMatchup-\(type)").firstMatch
            XCTAssertTrue(tile.exists, String(type))
            XCTAssertTrue(tile.isHittable, "\(type) is clipped or obscured")
        }
        XCTAssertEqual(app.scrollViews.count, 0)
    }

    func testSearchCanTypeClearAndRetype() {
        let app = XCUIApplication(); launch(app)
        let search = app.textFields["pokemonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        search.tap(); search.typeText("espeon")
        XCTAssertEqual(search.value as? String, "espeon")
        app.buttons["Clear search"].tap(); search.typeText("pikachu")
        XCTAssertEqual(search.value as? String, "pikachu")
    }
    // Seed Photos with the Espeon fixture using simctl addmedia before these tests.
    private func importEspeon(_ app: XCUIApplication) {
        let scan = app.buttons["phoneScan"].exists ? app.buttons["phoneScan"] : app.buttons["SCAN POKÉMON"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        scan.tap(); app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.tap()
    }
    func testImportAutomaticallyLoadsConfidentMatch() {
        let app = XCUIApplication(); launch(app)
        importEspeon(app)
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 30), app.debugDescription)
    }
    func testImportAndCandidateLookup() {
        let app = XCUIApplication(); app.launchArguments = ["--confirm-scans"]; launch(app)
        importEspeon(app)
        let candidate = app.buttons["scanCandidate-196"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 30), app.debugDescription)
        candidate.tap()
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 20), app.debugDescription)
    }
}
