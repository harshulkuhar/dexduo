import XCTest

final class EvolutionUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func open(_ app: XCUIApplication) throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        let cover = app.buttons["phoneCover"]
        if cover.waitForExistence(timeout: 3) { cover.tap() }
        let duoCover = app.descendants(matching: .any).matching(identifier: "duoCover").firstMatch
        if duoCover.exists { throw XCTSkip("Unfold Duo to exercise its interior.") }
        XCTAssertTrue(app.textFields["pokemonSearch"].waitForExistence(timeout: 20))
    }
    private func select(_ name: String, in app: XCUIApplication) {
        let search = app.textFields["pokemonSearch"]
        search.tap(); search.typeText(name)
        let candidate = app.buttons["searchCandidate-\(name)"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 10)); candidate.tap()
        XCTAssertTrue(app.staticTexts[name.uppercased()].waitForExistence(timeout: 20))
    }
    private func visible(_ element: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard element.exists, scroll.frame.insetBy(dx: -2, dy: -2).contains(element.frame) else { return false }
        return element.elementType != .button || element.isHittable
    }
    private func reveal(_ element: XCUIElement, in scroll: XCUIElement, limit: Int = 18) {
        for _ in 0..<limit {
            if visible(element, in: scroll) { return }
            let above = element.exists && element.frame.midY < scroll.frame.midY
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.4 : 0.75))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.75 : 0.4))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(visible(element, in: scroll), "Element is not reachable: \(element)")
    }
    private func capture(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertBranch(_ child: XCUIElement, from parent: XCUIElement, in scroll: XCUIElement) {
        XCTAssertGreaterThan(child.frame.minX - parent.frame.minX, 70)
        XCTAssertLessThan(child.frame.width, parent.frame.width)
        XCTAssertLessThanOrEqual(child.frame.maxX, scroll.frame.maxX)
    }
    func testVerticalChartShowsRequirementsAndRetainsMemberSelection() throws {
        let app = XCUIApplication(); try open(app)
        select("gastly", in: app)
        app.buttons["detailTab-evolution"].tap()
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30), app.debugDescription)
        let gastly = app.buttons["evolutionNode-gastly"]
        let haunter = app.buttons["evolutionNode-haunter"]
        let gengar = app.buttons["evolutionNode-gengar"]
        XCTAssertLessThan(gastly.frame.maxY, haunter.frame.minY)
        XCTAssertLessThan(haunter.frame.maxY, gengar.frame.minY)
        XCTAssertEqual(gastly.frame.minX, haunter.frame.minX, accuracy: 1)
        XCTAssertEqual(haunter.frame.width, gengar.frame.width, accuracy: 1)
        let level = app.descendants(matching: .any).matching(identifier: "evolutionCondition-haunter").firstMatch
        let trade = app.descendants(matching: .any).matching(identifier: "evolutionCondition-gengar").firstMatch
        XCTAssertTrue(level.label.contains("Level 25"))
        XCTAssertTrue(trade.label.contains("Trade"))
        XCTAssertFalse(app.buttons["evolutionCondition-haunter"].exists)
        XCTAssertFalse(app.staticTexts["Tap a Pokémon to open it. Tap an arrow for its evolution methods."].exists)
        reveal(level, in: scroll)
        XCTAssertLessThanOrEqual(level.frame.maxX, haunter.frame.maxX)
        capture(name: "Vertical Gastly chain with inline requirements")
        reveal(haunter, in: scroll)
        let position = haunter.frame
        haunter.tap()
        XCTAssertTrue(app.staticTexts["HAUNTER"].waitForExistence(timeout: 20))
        XCTAssertEqual(haunter.frame.minY, position.minY, accuracy: 8)
        XCTAssertTrue(haunter.isSelected)
        XCTAssertTrue(app.buttons["detailTab-evolution"].isSelected)
        reveal(trade, in: scroll)
        XCTAssertFalse(app.buttons["evolutionBack"].exists)
    }
    func testGeodudeHasSeparateNormalAndAlolanRoutes() throws {
        let app = XCUIApplication(); try open(app)
        select("geodude", in: app)
        app.buttons["detailTab-evolution"].tap()
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30), app.debugDescription)
        let level = app.descendants(matching: .any).matching(identifier: "evolutionCondition-graveler").firstMatch
        let regional = app.descendants(matching: .any).matching(identifier: "evolutionCondition-graveler-alola").firstMatch
        XCTAssertEqual(level.label, "Evolve into Graveler: Level 25")
        XCTAssertEqual(regional.label, "Evolve into Graveler Alola: Level 25 (Geodude Alola)")
        for name in ["graveler", "golem", "graveler-alola", "golem-alola"] {
            let node = app.buttons["evolutionNode-\(name)"]
            reveal(node, in: scroll)
            XCTAssertGreaterThanOrEqual(node.frame.minX, scroll.frame.minX)
            XCTAssertLessThanOrEqual(node.frame.maxX, scroll.frame.maxX)
        }
        capture(name: "Separate Geodude form routes")
    }
    func testPikachuBranchesUseOnlyStoneAndRegionLabels() throws {
        let app = XCUIApplication(); try open(app)
        select("pikachu", in: app)
        app.buttons["detailTab-evolution"].tap()
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30), app.debugDescription)
        let normal = app.descendants(matching: .any).matching(identifier: "evolutionCondition-raichu").firstMatch
        let alola = app.descendants(matching: .any).matching(identifier: "evolutionCondition-raichu-alola").firstMatch
        XCTAssertEqual(normal.label, "Evolve into Raichu: Thunder Stone")
        XCTAssertEqual(alola.label, "Evolve into Raichu Alola: Thunder Stone (Alola)")
        XCTAssertNotEqual(normal.frame, alola.frame)
        let regional = app.buttons["evolutionNode-raichu-alola"]
        reveal(regional, in: scroll)
        capture(name: "Pikachu separate Raichu and Alolan Raichu branches")
        let position = regional.frame
        regional.tap()
        XCTAssertTrue(app.staticTexts["RAICHU ALOLA"].waitForExistence(timeout: 20))
        XCTAssertTrue(regional.isSelected)
        XCTAssertEqual(regional.value as? String, "Electric, Psychic")
        XCTAssertTrue(app.buttons["detailTab-evolution"].isSelected)
        XCTAssertEqual(regional.frame.minY, position.minY, accuracy: 8)
        XCTAssertEqual(app.buttons.matching(identifier: "evolutionNode-pikachu").count, 1)
        XCTAssertTrue(app.staticTexts["No. 0026"].exists)
        app.buttons["Previous Pokémon"].tap()
        XCTAssertTrue(app.staticTexts["PIKACHU"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["No. 0025"].exists)
    }
    func testKirliaAndSnoruntHaveSeparateGenderRestrictedArrows() throws {
        let app = XCUIApplication(); try open(app)
        for (name, first, second, firstRequirement, secondRequirement) in [
            ("kirlia", "gardevoir", "gallade", "Level 30", "Dawn Stone (male)"),
            ("snorunt", "glalie", "froslass", "Level 42", "Dawn Stone (female)")
        ] {
            select(name, in: app)
            app.buttons["detailTab-evolution"].tap()
            let scroll = app.scrollViews["evolutionScroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 30))
            let firstArrow = app.descendants(matching: .any).matching(identifier: "evolutionCondition-\(first)").firstMatch
            let secondArrow = app.descendants(matching: .any).matching(identifier: "evolutionCondition-\(second)").firstMatch
            XCTAssertTrue(firstArrow.label.hasSuffix(firstRequirement))
            XCTAssertTrue(secondArrow.label.hasSuffix(secondRequirement))
            XCTAssertNotEqual(firstArrow.frame, secondArrow.frame)
            let firstNode = app.buttons["evolutionNode-\(first)"]
            let secondNode = app.buttons["evolutionNode-\(second)"]
            let parent = app.buttons["evolutionNode-\(name)"]
            reveal(firstNode, in: scroll)
            assertBranch(firstNode, from: parent, in: scroll)
            XCTAssertGreaterThan(firstArrow.frame.minX, parent.frame.minX)
            XCTAssertLessThan(firstArrow.frame.maxX, firstNode.frame.minX)
            XCTAssertLessThan(firstArrow.frame.maxY, firstNode.frame.midY)
            let column = firstNode.frame.minX
            reveal(secondNode, in: scroll)
            XCTAssertEqual(secondNode.frame.minX, column, accuracy: 1)
            XCTAssertLessThan(secondArrow.frame.maxX, secondNode.frame.minX)
            XCTAssertLessThan(secondArrow.frame.maxY, secondNode.frame.midY)
            capture(name: "\(name) separate evolution arrows")
        }
        app.buttons["evolutionNode-froslass"].tap()
        XCTAssertTrue(app.staticTexts["FROSLASS"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.buttons["evolutionNode-froslass"].value as? String, "Ice, Ghost")
    }
    func testEveryEeveeBranchIsReachableAndOnlyLCDScrolls() throws {
        let app = XCUIApplication(); try open(app)
        select("eevee", in: app)
        app.buttons["detailTab-evolution"].tap()
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30), app.debugDescription)
        let artwork = app.otherElements["phoneArtworkPanel"].exists ? app.otherElements["phoneArtworkPanel"] : app.staticTexts["EEVEE"]
        let artworkFrame = artwork.frame
        let tabFrame = app.buttons["detailTab-evolution"].frame
        let details = app.otherElements["phoneDetailsPanel"]
        XCTAssertTrue(details.frame.insetBy(dx: -2, dy: -2).contains(scroll.frame))
        XCTAssertGreaterThan(scroll.frame.minY, tabFrame.maxY)
        let names = ["vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon", "sylveon"]
        var column: CGFloat?
        for name in names {
            let node = app.buttons["evolutionNode-\(name)"]
            reveal(node, in: scroll)
            assertBranch(node, from: app.buttons["evolutionNode-eevee"], in: scroll)
            if let column { XCTAssertEqual(node.frame.minX, column, accuracy: 1) } else { column = node.frame.minX }
        }
        XCTAssertEqual(artwork.frame, artworkFrame)
        XCTAssertEqual(app.buttons["detailTab-evolution"].frame, tabFrame)
        XCTAssertEqual(app.scrollViews.count, 1)
        capture(name: "Eevee branches scrolled to Sylveon")
        let sylveon = app.buttons["evolutionNode-sylveon"]
        let oldPosition = sylveon.frame
        sylveon.tap()
        XCTAssertTrue(app.staticTexts["SYLVEON"].waitForExistence(timeout: 20))
        XCTAssertTrue(visible(sylveon, in: scroll))
        XCTAssertEqual(sylveon.frame.minY, oldPosition.minY, accuracy: 8)
        XCTAssertTrue(app.buttons["detailTab-evolution"].isSelected)
        XCTAssertEqual(sylveon.value as? String, "Fairy")
        app.buttons["detailTab-types"].tap()
        XCTAssertTrue(app.otherElements["typeGrid"].exists)
        XCTAssertEqual(app.scrollViews.count, 0)
    }
    func testStandaloneAndUnevenBranchDepth() throws {
        let app = XCUIApplication(); try open(app)
        select("ditto", in: app)
        app.buttons["detailTab-evolution"].tap()
        XCTAssertTrue(app.staticTexts["evolutionStandalone"].waitForExistence(timeout: 30))
        select("applin", in: app)
        let scroll = app.scrollViews["evolutionScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 30))
        for name in ["flapple", "appletun", "dipplin", "hydrapple"] { reveal(app.buttons["evolutionNode-\(name)"], in: scroll) }
        capture(name: "Applin branching stages")
    }
    func testContinuingBranchesStayInTheirOwnColumns() throws {
        let app = XCUIApplication(); try open(app)
        for (species, branches) in [
            ("wurmple", [("silcoon", "beautifly"), ("cascoon", "dustox")]),
            ("applin", [("dipplin", "hydrapple")])
        ] {
            select(species, in: app); app.buttons["detailTab-evolution"].tap()
            let scroll = app.scrollViews["evolutionScroll"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 30))
            for (branch, continuation) in branches {
                let child = app.buttons["evolutionNode-\(branch)"]
                reveal(child, in: scroll)
                assertBranch(child, from: app.buttons["evolutionNode-\(species)"], in: scroll)
                let column = child.frame.minX
                let next = app.buttons["evolutionNode-\(continuation)"]
                reveal(next, in: scroll)
                XCTAssertEqual(next.frame.minX, column, accuracy: 1)
            }
            capture(name: "\(species) aligned branch continuations")
        }
    }
    func testInfoStatsScrollAndTypesStayFixedInBothDirections() throws {
        let app = XCUIApplication(); try open(app)
        select("gastly", in: app)
        let artwork = app.otherElements["phoneArtworkPanel"].exists ? app.otherElements["phoneArtworkPanel"] : app.staticTexts["GASTLY"]
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            app.buttons["detailTab-info"].tap()
            var previous = CGRect.null
            let aligned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let current = artwork.frame
                let details = app.otherElements["phoneDetailsPanel"].frame
                let stable = current == previous
                previous = current
                return stable && abs(current.minY - details.minY) < 1 && current.width > 0
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [aligned], timeout: 8), .completed)
            let frame = artwork.frame
            let info = app.scrollViews["infoScroll"]
            XCTAssertTrue(info.exists)
            reveal(app.descendants(matching: .any).matching(identifier: "pokemonWeight").firstMatch, in: info)
            XCTAssertEqual(artwork.frame, frame)
            app.buttons["detailTab-stats"].tap()
            let stats = app.scrollViews["statsScroll"]
            reveal(app.staticTexts["phoneAbilities"], in: stats)
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "baseStatTotal").firstMatch.exists)
            XCTAssertFalse(app.buttons["statsNextPage"].exists)
            app.buttons["detailTab-types"].tap()
            XCTAssertEqual(app.scrollViews.count, 0)
            XCTAssertTrue(app.otherElements["typeGrid"].exists)
        }
    }
}
