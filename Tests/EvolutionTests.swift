import XCTest
import UIKit
@testable import DexDuo

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
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let family = try await repository.family(for: "haunter")
        let line = family.chain.flattened
        XCTAssertEqual(line.map(\.id), ["gastly", "haunter", "gengar"])
        XCTAssertEqual(line[1].conditions, ["Level 25"])
        XCTAssertEqual(line[2].conditions, ["Trade"])
    }
    func testEeveeRetainsAllEightBranchesAndAlternatives() async throws {
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let family = try await repository.family(for: "eevee")
        XCTAssertEqual(family.chain.evolves_to.map(\.id), ["vaporeon", "jolteon", "flareon", "espeon", "umbreon", "leafeon", "glaceon", "sylveon"])
        let leafeon = try XCTUnwrap(family.chain.evolves_to.first { $0.id == "leafeon" })
        XCTAssertTrue(leafeon.conditions[0].hasPrefix("Use Leaf Stone"))
        XCTAssertTrue(leafeon.conditions.contains { $0.contains("Location: Eterna Forest") && $0.contains("Introduced: Diamond Pearl") })
        let espeon = try XCTUnwrap(family.chain.evolves_to.first { $0.id == "espeon" })
        XCTAssertTrue(espeon.conditions[0].contains("Friendship ≥ 160"))
        XCTAssertTrue(espeon.conditions[0].contains("Time: Day"))
        XCTAssertGreaterThan(leafeon.evolution_details.count, 1)
        XCTAssertTrue(leafeon.evolution_details.contains { $0.requirements.contains("Location: Eterna Forest") })
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
    func testRegionalRequirementsAreExplicit() async throws {
        let family = try await EvolutionRepository(api: try EvolutionFixtureAPI()).family(for: "mr-mime")
        let rime = try XCTUnwrap(family.chain.flattened.first { $0.id == "mr-rime" })
        XCTAssertTrue(rime.conditions[0].hasPrefix("Level 42"))
        XCTAssertTrue(rime.conditions[0].contains("Required form: Mr Mime Galar"))
        XCTAssertTrue(rime.evolution_details[0].requirements.contains("Required form: Mr Mime Galar"))
        XCTAssertTrue(rime.evolution_details[0].requirements.contains("Level 42"))
    }
    func testCompoundConditionsUnknownFieldsAndIntrinsicConditions() throws {
        let data = Data(#"{"trigger":{"name":"level-up"},"min_level":30,"held_item":{"name":"razor-claw"},"time_of_day":"night","gender":1,"min_steps":1000,"needs_multiplayer":true,"new_requirement":true}"#.utf8)
        let method = try JSONDecoder().decode(EvolutionMethod.self, from: data)
        for line in ["Level 30", "Holding: Razor Claw", "Time: Night", "Gender: Female", "Steps ≥ 1000", "Multiplayer required"] {
            XCTAssertTrue(method.requirements.contains(line), line)
        }
        XCTAssertTrue(method.hasUnresolvedRequirements)
        let expression = try JSONDecoder().decode(EvolutionMethod.self, from: Data(#"{"trigger":{"name":"level-up"},"condition_expression":{"expression":"EC 10 % 0 ==","percentage_chance":10}}"#.utf8))
        XCTAssertTrue(expression.hasUnresolvedRequirements)
        XCTAssertTrue(expression.requirements.contains { $0.contains("10%") })
    }
    func testGeodudeDisplaysRequirementsInsteadOfGenericMethods() async throws {
        let family = try await EvolutionRepository(api: try EvolutionFixtureAPI()).family(for: "geodude")
        let nodes = family.chain.flattened
        XCTAssertEqual(nodes.map(\.id), ["geodude", "graveler", "golem"])
        XCTAssertTrue(nodes[1].conditions[0].hasPrefix("Level 25"))
        XCTAssertTrue(nodes[2].conditions[0].hasPrefix("Trade"))
        XCTAssertTrue(nodes[1].conditions[1].contains("Required form: Geodude Alola"))
        XCTAssertTrue(nodes[2].conditions[1].contains("Resulting form: Golem Alola"))
        XCTAssertTrue(nodes[2].conditions[1].contains("Introduced: Sun Moon"))
        XCTAssertFalse(nodes.flatMap(\.conditions).contains { $0.contains("Methods") })
    }
    func testInlineConditionsKeepCompoundRequirementsAndDeduplicate() throws {
        let data = Data(#"{"species":{"name":"test","url":""},"evolves_to":[],"evolution_details":[{"trigger":{"name":"use-item"},"item":{"name":"water-stone"}},{"is_default":true,"trigger":{"name":"level-up"},"min_happiness":160,"time_of_day":"night","unknown_condition":true},{"trigger":{"name":"use-item"},"item":{"name":"water-stone"}}]}"#.utf8)
        let link = try JSONDecoder().decode(EvolutionLink.self, from: data)
        XCTAssertEqual(link.conditions.count, 2)
        for requirement in ["Level up", "Friendship ≥ 160", "Time: Night", "Additional requirements are not fully described here."] {
            XCTAssertTrue(link.conditions[0].contains(requirement))
        }
        XCTAssertEqual(link.conditions[1], "Use Water Stone")
        let unavailable = try JSONDecoder().decode(EvolutionLink.self, from: Data(#"{"species":{"name":"test","url":""},"evolves_to":[],"evolution_details":[]}"#.utf8))
        XCTAssertEqual(unavailable.conditions, ["Evolution requirements are not available."])
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
    private func finish(_ model: EvolutionModel) async {
        for _ in 0..<200 where model.choosing != nil { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertNil(model.choosing)
    }
}
