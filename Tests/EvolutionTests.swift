import XCTest
import UIKit
import SwiftUI
@testable import DexDuo

final class EvolutionConnectorTests: XCTestCase {
    func testArrowSpaceAdaptsWithoutSqueezingCards() {
        XCTAssertEqual(EvolutionForkRow.gutter(lcdWidth: 240), 80)
        XCTAssertEqual(EvolutionForkRow.gutter(lcdWidth: 296), 132)
        XCTAssertEqual(EvolutionForkRow.gutter(lcdWidth: 320), 132)
        XCTAssertEqual(EvolutionForkRow.gutter(lcdWidth: 600, preferred: 400), 270)
    }
    func testWrappedRequirementsStayAboveTheirArrowAndLeftOfTheirCard() {
        for (width, preferred, captionHeight, cardHeight) in [
            (240.0, 132.0, 68.0, 90.0), (338, 132, 34, 68), (640, 280, 160, 150)
        ] {
            let gutter = EvolutionForkRow.gutter(lcdWidth: width, preferred: preferred)
            let frames = EvolutionForkRow.frames(width: width, gutter: gutter, captionHeight: captionHeight, cardHeight: cardHeight)
            XCTAssertLessThan(frames.caption.maxX, frames.card.minX)
            XCTAssertEqual(frames.caption.maxY + 6, frames.card.midY, accuracy: 0.01)
            XCTAssertGreaterThanOrEqual(frames.caption.minY, 0)
            XCTAssertGreaterThanOrEqual(frames.card.minY, 0)
            XCTAssertEqual(frames.card.maxX, width)
            XCTAssertEqual(frames.caption.height, captionHeight)
        }
    }
    func testTrunkStopsAtLastSiblingRatherThanItsDescendants() {
        // Uneven families: the final sibling may itself continue far below the fork.
        let junctions = [CGPoint(x: 45, y: 80), CGPoint(x: 45, y: 230), CGPoint(x: 45, y: 480)]
        let path = EvolutionBranchLines(junctions: junctions).path(in: CGRect(x: 0, y: 0, width: 350, height: 900))
        var moves: [CGPoint] = [], lines: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint: moves.append(element.pointee.points[0])
            case .addLineToPoint: lines.append(element.pointee.points[0])
            default: XCTFail("Evolution forks use straight segments")
            }
        }
        XCTAssertEqual(moves.first, CGPoint(x: 12, y: 0))
        XCTAssertEqual(lines.first, CGPoint(x: 12, y: 480))
        for junction in junctions { XCTAssertTrue(lines.contains(junction)) }
        XCTAssertEqual(path.boundingRect.maxY, 484, "The trunk must not extend to the subtree bottom")
        XCTAssertLessThanOrEqual(path.boundingRect.maxX, 45)
    }
    func testNoDanglingTrunkForAbsentChildren() {
        XCTAssertTrue(EvolutionBranchLines(junctions: []).path(in: CGRect(x: 0, y: 0, width: 300, height: 300)).isEmpty)
    }
}

actor EvolutionFixtureAPI: DexFetching {
    private let responses: [String: Data]
    private let stripArtwork: Bool
    private var unavailable = false
    private var delays: [String: UInt64] = [:]
    private var counts: [String: Int] = [:]
    init(stripArtwork: Bool = true) throws {
        let url = try XCTUnwrap(Bundle(for: EvolutionTests.self).url(forResource: "Evolution", withExtension: "json"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let rows = try XCTUnwrap(document["responses"] as? [String: Any])
        responses = try rows.mapValues { try JSONSerialization.data(withJSONObject: $0) }
        self.stripArtwork = stripArtwork
    }
    func setUnavailable(_ value: Bool) { unavailable = value }
    func delay(_ path: String, milliseconds: UInt64) { delays[path] = milliseconds * 1_000_000 }
    func count(_ path: String) -> Int { counts[path, default: 0] }
    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        counts[path, default: 0] += 1
        // Deliberately ignore cooperative cancellation to exercise generation guards.
        if let delay = delays[path] { try? await Task.sleep(nanoseconds: delay) }
        guard !unavailable, var data = responses[path] else { throw URLError(.notConnectedToInternet) }
        if stripArtwork && path.hasPrefix("pokemon/") {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object["sprites"] = ["front_default": NSNull()]
            data = try JSONSerialization.data(withJSONObject: object)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private actor ThumbnailCounter {
    var count = 0
    func increment() { count += 1 }
}

final class EvolutionTests: XCTestCase {
    func testGastlyMatchesReference() async throws {
        let family = try await EvolutionRepository(api: try EvolutionFixtureAPI()).family(for: "haunter")
        let nodes = family.tree.flattened
        XCTAssertEqual(nodes.map(\.id), ["gastly", "haunter", "gengar"])
        XCTAssertEqual(nodes[1].conditions, ["Level 25"])
        XCTAssertEqual(nodes[2].conditions, ["Trade"])
    }
    func testEeveeShowsEightBranchesWithoutHistoricalMethodBloat() async throws {
        let family = try await EvolutionRepository(api: try EvolutionFixtureAPI()).family(for: "eevee")
        XCTAssertEqual(family.tree.children.map(\.id), ["vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon", "sylveon"])
        let leafeon = try XCTUnwrap(family.tree.children.first { $0.id == "leafeon" })
        XCTAssertEqual(leafeon.conditions, ["Leaf Stone"])
        let espeon = try XCTUnwrap(family.tree.children.first { $0.id == "espeon" })
        XCTAssertEqual(espeon.conditions, ["Friendship ≥ 160 (day)"])
        XCTAssertFalse(family.tree.flattened.flatMap(\.conditions).contains { $0.contains("Introduced:") || $0.contains("Required form:") })
    }
    func testBranchingStagesUnevenDepthAndStandalone() async throws {
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let wurmple = try await repository.family(for: "wurmple")
        XCTAssertEqual(wurmple.chain.flattened.map(\.id), ["wurmple", "silcoon", "beautifly", "cascoon", "dustox"])
        let applin = try await repository.family(for: "applin")
        XCTAssertEqual(applin.chain.evolves_to.count, 3)
        XCTAssertTrue(applin.chain.flattened.contains { $0.id == "hydrapple" })
        let ditto = try await repository.family(for: "ditto")
        XCTAssertTrue(ditto.chain.evolves_to.isEmpty)
    }
    func testDefaultVarietyMappingAndFamilyCacheWorkOffline() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let deoxys = try await repository.member(for: "deoxys")
        XCTAssertEqual(deoxys.name, "deoxys-normal")
        XCTAssertNil(deoxys.artwork, "Absent artwork must not become an empty relative URL")
        let family = try await repository.family(for: "eevee")
        _ = try await repository.member(for: "jolteon")
        await api.setUnavailable(true)
        let cached = try await repository.family(for: "sylveon")
        XCTAssertEqual(cached.id, family.id)
        let member = try await repository.member(for: "jolteon")
        XCTAssertEqual(member.name, "jolteon")
        let calls = await api.count("evolution-chain/67")
        XCTAssertEqual(calls, 1)
    }
    func testConcurrentFamilyRequestsCoalesceAndFailureCanRetry() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        await api.delay("evolution-chain/67", milliseconds: 40)
        async let first = repository.family(for: "eevee")
        async let second = repository.family(for: "espeon")
        let values = try await [first, second]
        XCTAssertEqual(values.map(\.id), [67, 67])
        let count = await api.count("evolution-chain/67")
        XCTAssertEqual(count, 1)
        await api.setUnavailable(true)
        do { _ = try await repository.member(for: "gastly"); XCTFail("Expected unavailable data") } catch {}
        await api.setUnavailable(false)
        let gastly = try await repository.member(for: "gastly")
        XCTAssertEqual(gastly.name, "gastly")
    }
    func testRegionalBranchesStayOnTheirCorrectParentForms() async throws {
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let family = try await repository.family(for: "mr-mime")
        let mime = try XCTUnwrap(family.tree.children.first { $0.id == "mr-mime" })
        let galar = try XCTUnwrap(family.tree.children.first { $0.id == "mr-mime-galar" })
        XCTAssertTrue(mime.children.isEmpty)
        XCTAssertEqual(galar.children.map(\.id), ["mr-rime"])
        XCTAssertEqual(galar.children[0].conditions, ["Level 42"])
        let geodude = try await repository.family(for: "geodude")
        XCTAssertEqual(geodude.tree.children.map(\.id), ["graveler", "graveler-alola"])
        XCTAssertEqual(geodude.tree.children[0].conditions, ["Level 25"])
        XCTAssertEqual(geodude.tree.children[1].conditions, ["Level 25 (Geodude Alola)"])
        XCTAssertEqual(geodude.tree.children[0].children.map(\.id), ["golem"])
        XCTAssertEqual(geodude.tree.children[1].children.map(\.id), ["golem-alola"])
    }
    func testCompoundConditionsUnknownFieldsAndIntrinsicConditions() throws {
        let data = Data(#"{"trigger":{"name":"level-up"},"min_level":30,"held_item":{"name":"razor-claw"},"time_of_day":"night","gender":1,"min_steps":1000,"needs_multiplayer":true,"new_requirement":true}"#.utf8)
        let method = try JSONDecoder().decode(EvolutionMethod.self, from: data)
        for condition in ["Level 30", "Holding: Razor Claw", "night", "female", "Steps ≥ 1000", "Multiplayer", "Other requirements unknown"] {
            XCTAssertTrue(method.label().contains(condition), condition)
        }
        XCTAssertTrue(method.hasUnresolvedRequirements)
        let expression = try JSONDecoder().decode(EvolutionMethod.self, from: Data(#"{"trigger":{"name":"level-up"},"condition_expression":{"expression":"EC 10 % 0 ==","percentage_chance":10}}"#.utf8))
        XCTAssertTrue(expression.hasUnresolvedRequirements)
        XCTAssertTrue(expression.label().contains("10%"))
    }
    func testPikachuFormsHaveDistinctNodesAndConciseConditions() async throws {
        let family = try await EvolutionRepository(api: try EvolutionFixtureAPI()).family(for: "pikachu")
        let pikachu = try XCTUnwrap(family.tree.children.first)
        XCTAssertEqual(pikachu.children.map(\.id), ["raichu", "raichu-alola"])
        XCTAssertEqual(pikachu.children[0].conditions, ["Thunder Stone"])
        XCTAssertEqual(pikachu.children[1].conditions, ["Thunder Stone (Alola)"])
        XCTAssertEqual(pikachu.children[1].species.name, "raichu")
        XCTAssertEqual(pikachu.children[1].title, "Raichu Alola")
    }
    func testKirliaAndSnoruntGenderConditionsAreNotLost() async throws {
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let ralts = try await repository.family(for: "kirlia")
        let kirlia = try XCTUnwrap(ralts.tree.children.first)
        XCTAssertEqual(kirlia.children.map(\.id), ["gardevoir", "gallade"])
        XCTAssertEqual(kirlia.children.map(\.conditions), [["Level 30"], ["Dawn Stone (male)"]])
        let snorunt = try await repository.family(for: "snorunt")
        XCTAssertEqual(snorunt.tree.children.map(\.id), ["glalie", "froslass"])
        XCTAssertEqual(snorunt.tree.children.map(\.conditions), [["Level 42"], ["Dawn Stone (female)"]])
    }
    func testAllNineteenSpeciesBranchSplitsMatchOfficialSource() async throws {
        struct Check: Decodable { let chainID: Int; let parent: String; let children: [String] }
        struct Document: Decodable { let branch_expectations: [Check] }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Evolution", withExtension: "json"))
        let checks = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).branch_expectations
        XCTAssertEqual(checks.count, 19)
        let api = try EvolutionFixtureAPI()
        for check in checks {
            let family = try await api.get("evolution-chain/\(check.chainID)", as: EvolutionChain.self)
            let parents = family.tree.flattened.filter { $0.species.name == check.parent }
            let children = Set(parents.flatMap(\.children).map { $0.species.name })
            XCTAssertEqual(children, Set(check.children), check.parent)
            XCTAssertEqual(Set(family.tree.flattened.map(\.id)).count, family.tree.flattened.count, "Duplicate node: \(check.parent)")
        }
    }
    func testFormResolutionUsesPokemonIdentifierAndCachesOffline() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let family = try await repository.family(for: "pikachu")
        let alola = try XCTUnwrap(family.tree.flattened.first { $0.id == "raichu-alola" })
        let member = try await repository.member(for: alola.species.name, form: alola.form)
        XCTAssertEqual(member.name, "raichu-alola")
        XCTAssertEqual(member.nationalNumber, 26)
        XCTAssertEqual(member.types.map { $0.type.name }, ["electric", "psychic"])
        await api.setUnavailable(true)
        let cached = try await repository.member(for: alola.species.name, form: alola.form)
        XCTAssertEqual(cached.name, member.name)
        let count = await api.count("pokemon-form/10202")
        XCTAssertEqual(count, 1)
    }
    func testLabelsDeduplicateAndMissingConditionsStayUnknown() throws {
        let data = Data(#"{"species":{"name":"test","url":""},"evolves_to":[],"evolution_details":[{"trigger":{"name":"use-item"},"item":{"name":"water-stone"}},{"trigger":{"name":"use-item"},"item":{"name":"water-stone"}}]}"#.utf8)
        let link = try JSONDecoder().decode(EvolutionLink.self, from: data)
        XCTAssertEqual(EvolutionBranch(link: link, methods: link.evolution_details).conditions, ["Water Stone"])
        let unavailable = try JSONDecoder().decode(EvolutionLink.self, from: Data(#"{"species":{"name":"test","url":""},"evolves_to":[],"evolution_details":[]}"#.utf8))
        XCTAssertEqual(EvolutionBranch(link: unavailable).conditionText, "Requirements unknown")
    }

}

@MainActor final class EvolutionLifecycleTests: XCTestCase {
    func testLatestFamilyWinsAndCancelledLoadCannotPublish() async throws {
        let api = try EvolutionFixtureAPI()
        await api.delay("evolution-chain/40", milliseconds: 100)
        let model = EvolutionModel(repository: EvolutionRepository(api: api))
        let old = Task { await model.load(for: "gastly") }
        try await Task.sleep(for: .milliseconds(20))
        await model.load(for: "eevee")
        await old.value
        XCTAssertEqual(model.chain?.id, 67)
        let cancelled = EvolutionModel(repository: EvolutionRepository(api: api))
        let load = Task { await cancelled.load(for: "gastly") }
        try await Task.sleep(for: .milliseconds(20)); cancelled.cancel()
        await load.value
        XCTAssertNil(cancelled.chain)
        XCTAssertNil(cancelled.error)
        XCTAssertTrue(cancelled.members.isEmpty)
        XCTAssertTrue(cancelled.thumbnails.isEmpty)
    }
    func testUnavailableFamilyRetriesAndMissingThumbnailsDoNotBlockNodes() async throws {
        let api = try EvolutionFixtureAPI(stripArtwork: false)
        await api.setUnavailable(true)
        let model = EvolutionModel(repository: EvolutionRepository(api: api), thumbnail: { _ in throw URLError(.cannotDecodeContentData) })
        await model.load(for: "gastly")
        XCTAssertNotNil(model.error)
        await api.setUnavailable(false)
        await model.load(for: "gastly")
        XCTAssertNil(model.error)
        XCTAssertEqual(model.members.count, 3)
        XCTAssertTrue(model.thumbnails.isEmpty)
    }
    func testSameFamilyRetainsAnchorAndDecodedThumbnails() async throws {
        let api = try EvolutionFixtureAPI(stripArtwork: false)
        let thumbnails = ThumbnailCounter()
        let model = EvolutionModel(repository: EvolutionRepository(api: api), thumbnail: { _ in
            await thumbnails.increment()
            return UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in UIColor.cyan.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        })
        await model.load(for: "gastly")
        model.scrollAnchor = "haunter"
        let image = model.thumbnails["haunter"]
        model.cancel()
        await model.load(for: "gengar")
        XCTAssertEqual(model.scrollAnchor, "haunter")
        XCTAssertTrue(image === model.thumbnails["haunter"])
        let count = await thumbnails.count
        XCTAssertEqual(count, 3)
    }
    func testInlineSelectionFailureRetainsPokemonAndRetrySucceeds() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let store = DexStore(api: api)
        store.pokemon = try await repository.member(for: "gastly")
        let model = EvolutionModel(repository: repository)
        await model.load(for: "gastly")
        await api.setUnavailable(true)
        model.choose("haunter", store: store)
        await finish(model)
        XCTAssertEqual(store.pokemon?.name, "gastly")
        XCTAssertNil(store.error)
        XCTAssertEqual(model.failedMember, "haunter")
        XCTAssertNotNil(model.chain)
        await api.setUnavailable(false)
        model.choose("haunter", store: store)
        await finish(model)
        XCTAssertEqual(store.pokemon?.name, "haunter")
        XCTAssertNil(model.selectionError)
    }
    func testCancelledSelectionCannotChangePokemonOrReportLateError() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let store = DexStore(api: api)
        store.pokemon = try await repository.member(for: "gastly")
        let model = EvolutionModel(repository: repository)
        await model.load(for: "gastly")
        await api.delay("pokemon/gengar", milliseconds: 100)
        model.choose("gengar", store: store)
        try await Task.sleep(for: .milliseconds(20)); model.cancel()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(store.pokemon?.name, "gastly")
        XCTAssertNil(model.selectionError)
        XCTAssertNil(model.choosing)
    }
    func testCancellationDuringEntryFetchRetainsPreviousPokemonAndText() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let store = DexStore(api: api)
        store.pokemon = try await repository.member(for: "gastly")
        store.entryText = "Previous complete entry."
        store.entryVersion = "Red"
        let model = EvolutionModel(repository: repository)
        await model.load(for: "gastly")
        await api.delay("pokemon-species/haunter", milliseconds: 100)
        model.choose("haunter", store: store)
        try await Task.sleep(for: .milliseconds(20)); model.cancel()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(store.pokemon?.name, "gastly")
        XCTAssertEqual(store.entryText, "Previous complete entry.")
        XCTAssertEqual(store.entryVersion, "Red")
        XCTAssertFalse(store.loading)
    }
    func testRegionalSelectionRetainsFamilyAndExactForm() async throws {
        let api = try EvolutionFixtureAPI()
        let repository = EvolutionRepository(api: api)
        let store = DexStore(api: api)
        store.pokemon = try await repository.member(for: "pikachu")
        let model = EvolutionModel(repository: repository)
        await model.load(for: "pikachu")
        model.scrollAnchor = "raichu-alola"
        model.choose("raichu-alola", store: store)
        await finish(model)
        XCTAssertEqual(store.pokemon?.name, "raichu-alola")
        XCTAssertEqual(store.pokemon?.types.map { $0.type.name }, ["electric", "psychic"])
        await model.load(for: "raichu")
        XCTAssertEqual(model.scrollAnchor, "raichu-alola")
        XCTAssertEqual(model.chain?.id, 10)
        XCTAssertNil(model.selectionError)
    }
    private func finish(_ model: EvolutionModel) async {
        for _ in 0..<200 where model.choosing != nil { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertNil(model.choosing)
    }
}
