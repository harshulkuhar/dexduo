import XCTest

final class PhoneUITests: XCTestCase {
    private func open(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        if app.otherElements["duoPresentation"].waitForExistence(timeout: 2) || app.otherElements["tabletPresentation"].exists {
            throw XCTSkip("This test exercises the ordinary-phone presentation.")
        }
        let cover = app.buttons["phoneCover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 20), app.debugDescription)
        cover.tap()
        XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 15))
    }

    func testCoverPanelsAndBothLandscapeDirections() throws {
        let app = XCUIApplication()
        try open(app)
        XCTAssertTrue(app.staticTexts["PIKACHU"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["pokemonArtwork"].waitForExistence(timeout: 20))
        let artwork = app.otherElements["phoneArtworkPanel"]
        let details = app.otherElements["phoneDetailsPanel"]
        XCTAssertTrue(artwork.exists); XCTAssertTrue(details.exists)
        XCTAssertEqual(artwork.frame.width, details.frame.width, accuracy: 1)
        XCTAssertLessThan(artwork.frame.maxX, details.frame.minX)
        app.buttons["detailTab-types"].tap()
        assertAllTypes(app)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(app.textFields["pokemonSearch"].isHittable)
        assertAllTypes(app)
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 5))
        assertAllTypes(app)
        app.buttons["phoneCoverButton"].tap()
        XCTAssertTrue(app.buttons["phoneCover"].waitForExistence(timeout: 5))
        app.buttons["phoneCover"].tap()
        XCTAssertTrue(app.staticTexts["PIKACHU"].exists)
        XCTAssertTrue(app.images["pokemonArtwork"].exists, "Artwork must remain loaded when the cover reopens")
        assertAllTypes(app)
        XCTAssertEqual(app.scrollViews.count, 0)
    }

    func testTypingClearingAndSelectingWithKeyboard() throws {
        let app = XCUIApplication()
        try open(app)
        let search = app.textFields["pokemonSearch"]
        search.tap(); search.typeText("espeon")
        XCTAssertEqual(search.value as? String, "espeon")
        let result = app.buttons["searchCandidate-espeon"]
        XCTAssertTrue(result.waitForExistence(timeout: 15)); XCTAssertTrue(result.isHittable)
        result.tap()
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 20))
        search.tap(); search.typeText("gyarados")
        app.buttons["Clear search"].tap(); search.typeText("pikachu")
        XCTAssertEqual(search.value as? String, "pikachu")
        let pikachu = app.buttons["searchCandidate-pikachu"]
        XCTAssertTrue(pikachu.waitForExistence(timeout: 10)); pikachu.tap()
        XCTAssertTrue(app.staticTexts["PIKACHU"].waitForExistence(timeout: 20))
    }

    func testLandscapeScannerImportAndCandidateConfirmation() throws {
        let app = XCUIApplication(); app.launchArguments = ["--confirm-scans"]
        try open(app)
        app.buttons["phoneScan"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10)); photo.tap()
        let candidate = app.buttons["scanCandidate-196"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 40)); candidate.tap()
        XCTAssertTrue(app.staticTexts["ESPEON"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.scrollViews["infoScroll"].exists)
    }

    func testAccessibilityScrollingExposesEntryMeasurementsStatsAndTypes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        try open(app)
        XCTAssertTrue(app.staticTexts["PIKACHU"].waitForExistence(timeout: 20))
        let picker = app.segmentedControls["phonePanelPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Details"].tap()
        let entry = app.staticTexts["phoneEntryText"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); XCTAssertTrue(entry.isHittable)
        let info = app.scrollViews["infoScroll"]
        for _ in 0..<12 {
            if app.descendants(matching: .any).matching(identifier: "pokemonHeight").firstMatch.isHittable { break }
            info.swipeUp()
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pokemonHeight").firstMatch.isHittable)
        app.buttons["detailTab-stats"].tap()
        let stats = app.scrollViews["statsScroll"]
        for _ in 0..<12 {
            if app.staticTexts["phoneAbilities"].isHittable { break }
            stats.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["phoneAbilities"].isHittable)
        app.buttons["detailTab-types"].tap(); assertAllTypes(app)
        XCTAssertEqual(app.scrollViews.count, 0)
    }

    private func assertAllTypes(_ app: XCUIApplication) {
        for name in "normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy".split(separator: " ") {
            let tile = app.descendants(matching: .any).matching(identifier: "typeMatchup-\(name)").firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: 5), String(name))
            XCTAssertTrue(tile.isHittable, "\(name) is clipped")
            XCTAssertTrue(app.frame.contains(tile.frame), "\(name) extends outside the display")
        }
    }
}

final class DuoPresentationUITests: XCTestCase {
    func testDuoProfileAndUIKitOrientationStayFixed() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        if app.buttons["phoneCover"].waitForExistence(timeout: 3) || app.otherElements["tabletPresentation"].exists {
            throw XCTSkip("This regression test requires a Duo simulator.")
        }
        let duo = app.otherElements["duoPresentation"]
        XCTAssertTrue(duo.waitForExistence(timeout: 10), app.debugDescription)
        let cover = app.descendants(matching: .any).matching(identifier: "duoCover").firstMatch
        let search = app.textFields["pokemonSearch"]
        XCTAssertTrue(cover.exists || search.exists, app.debugDescription)
        let wasClosed = cover.exists
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(duo.exists)
            XCTAssertGreaterThan(app.frame.height, app.frame.width)
            XCTAssertEqual(cover.exists, wasClosed)
            if !wasClosed { XCTAssertTrue(search.exists) }
        }
    }
}
