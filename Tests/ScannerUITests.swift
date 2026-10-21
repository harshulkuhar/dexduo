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
        let scan = app.buttons["phoneScan"].exists ? app.buttons["phoneScan"] : app.buttons["scannerLens"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15), "Unfold the Duo simulator before running UI tests.")
        scan.tap(); XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30), app.debugDescription)
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

    func testEmbeddedScannerImportCancellationRetakeAndReopening() {
        let app = XCUIApplication(); app.launchArguments = ["--confirm-scans"]; launch(app)
        let scan = app.buttons["phoneScan"].exists ? app.buttons["phoneScan"] : app.buttons["scannerLens"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15)); scan.tap()
        let preview = app.otherElements["scanPreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertTrue(app.frame.contains(preview.frame))
        XCTAssertTrue(app.staticTexts["scanMessage"].label.contains("Simulator"))
        XCTAssertFalse(app.buttons["scanCapture"].isEnabled)
        app.buttons["scanImport"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10)); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5)); XCTAssertTrue(preview.exists)
        app.buttons["scanImport"].tap()
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH[c] 'Photo, '")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30)); photo.tap()
        XCTAssertTrue(app.buttons["scanCandidate-196"].waitForExistence(timeout: 40))
        app.buttons["scanImport"].tap(); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["scanCandidate-196"].exists, "Cancelling Import retains the previous result")
        app.buttons["scanRetake"].tap()
        XCTAssertFalse(app.buttons["scanCandidate-196"].exists)
        XCTAssertTrue(app.buttons["scanCapture"].exists)
        app.buttons["Done"].tap(); scan.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["Done"].isHittable)
        if app.otherElements["phoneScanner"].exists {
            XCUIDevice.shared.orientation = .landscapeRight
            XCTAssertTrue(app.buttons["scanImport"].isHittable); XCTAssertTrue(app.buttons["Done"].isHittable)
        }
        app.buttons["Done"].tap()
    }

    func testSupportAboutLinks() {
        let app = XCUIApplication(); launch(app)
        XCTAssertTrue(app.buttons["detailTab-info"].waitForExistence(timeout: 15))
        app.buttons["detailTab-info"].tap()
        let info = app.scrollViews["infoScroll"]
        let email = app.staticTexts["supportEmail"]
        for _ in 0..<5 where !email.isHittable { info.swipeUp() }
        XCTAssertEqual(email.label, "kuharharshul@gmail.com")
        let terms = app.descendants(matching: .any).matching(identifier: "supportTerms").firstMatch
        for _ in 0..<5 where !terms.isHittable { info.swipeUp() }
        XCTAssertTrue(terms.isHittable)
        XCTAssertTrue(app.textFields["pokemonSearch"].exists)
    }

    func testDoneWithoutCaptureReturnsPromptlyFromScanAndLens() {
        let app = XCUIApplication(); app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 4) { cover.tap() }
        XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 15))
        for identifier in ["phoneScan", "scannerLens"] {
            // Duo uses its lens; ordinary phones expose both entry points.
            if !app.buttons[identifier].exists { continue }
            for waitForLive in [false, true] {
                app.buttons[identifier].tap()
                let done = app.buttons["Done"]
                XCTAssertTrue(done.waitForExistence(timeout: 5))
                if waitForLive {
                    let capture = app.buttons["scanCapture"]
                    let ready = NSPredicate { _, _ in capture.isEnabled || app.staticTexts["scanMessage"].label.contains("Simulator") }
                    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 15), .completed)
                }
                let start = Date()
                done.tap()
                XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 5))
                let elapsed = Date().timeIntervalSince(start)
                print("SCANNER_DONE_SECONDS entry=\(identifier) live=\(waitForLive) elapsed=\(elapsed)")
                XCTAssertLessThan(elapsed, 2, "Done must not wait for native camera shutdown")
            }
        }
    }

    func testAccessibleScannerControlsOnBothPages() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launch(app)
        let scan = app.buttons["phoneScan"].exists ? app.buttons["phoneScan"] : app.buttons["scannerLens"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15)); scan.tap()
        if app.otherElements["phoneScanner"].waitForExistence(timeout: 3) {
            for panel in ["Preview", "Results"] {
                app.segmentedControls.buttons[panel].tap()
                XCTAssertTrue(app.buttons["scanImport"].isHittable)
                XCTAssertTrue(app.buttons["scanCapture"].exists)
                XCTAssertTrue(app.buttons["Done"].isHittable)
            }
        } else {
            XCTAssertTrue(app.buttons["scanImport"].isHittable); XCTAssertTrue(app.buttons["Done"].isHittable)
        }
        app.buttons["Done"].tap()
    }
}
