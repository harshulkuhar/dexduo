import XCTest
@testable import DexDuo

final class TypeChartTests: XCTestCase {
    private func chart() throws -> TypeChart {
        try TypeChart.load(bundle: Bundle(for: DexStore.self))
    }

    private func multipliers(_ names: [String]) throws -> [PokemonType: Double] {
        Dictionary(uniqueKeysWithValues: try chart().matchups(defending: names).map { ($0.type, $0.multiplier) })
    }

    func testEverySingleTypeRelationshipAgainstPinnedSource() throws {
        let bundle = Bundle(for: Self.self)
        let namesURL = try XCTUnwrap(bundle.url(forResource: "types", withExtension: "csv"))
        let relationsURL = try XCTUnwrap(bundle.url(forResource: "type_efficacy", withExtension: "csv"))
        let names = try String(contentsOf: namesURL, encoding: .utf8).split(separator: "\n").dropFirst().map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let byID = Dictionary(uniqueKeysWithValues: names.map { ($0[0], $0[1]) })
        let relations = try String(contentsOf: relationsURL, encoding: .utf8).split(separator: "\n").dropFirst()
        let chart = try chart()
        var verified = 0
        for row in relations {
            let values = row.split(separator: ",").map(String.init)
            guard let attackerName = byID[values[0]], let attacker = PokemonType(rawValue: attackerName),
                  let defenderName = byID[values[1]], PokemonType(rawValue: defenderName) != nil else { continue }
            let actual = try chart.matchups(defending: [defenderName]).first { $0.type == attacker }
            XCTAssertEqual(try XCTUnwrap(actual).multiplier, try XCTUnwrap(Double(values[2])) / 100, "\(attackerName) against \(defenderName)")
            verified += 1
        }
        XCTAssertEqual(verified, 324)
    }

    func testGyaradosMatchesReference() throws {
        let actual = try multipliers(["water", "flying"])
        let expected: [PokemonType: Double] = [.normal: 1, .fire: 0.5, .water: 0.5, .electric: 4,
            .grass: 1, .ice: 1, .fighting: 0.5, .poison: 1, .ground: 0, .flying: 1, .psychic: 1,
            .bug: 0.5, .rock: 2, .ghost: 1, .dragon: 1, .dark: 1, .steel: 0.5, .fairy: 1]
        XCTAssertEqual(actual, expected)
    }

    func testCombinedTypesAndImmunities() throws {
        let charizard = try multipliers(["fire", "flying"])
        XCTAssertEqual(charizard[.rock], 4)
        XCTAssertEqual(charizard[.grass], 0.25)
        XCTAssertEqual(charizard[.ground], 0)
        XCTAssertEqual(try multipliers(["bug", "steel"])[.fire], 4)
        XCTAssertEqual(try multipliers(["electric"])[.ground], 2)
        let normalGhost = try multipliers(["normal", "ghost"])
        XCTAssertEqual(normalGhost[.normal], 0)
        XCTAssertEqual(normalGhost[.fighting], 0)
        XCTAssertEqual(normalGhost[.ghost], 0)
    }

    func testTypeOrderDuplicatesAndInvalidInputs() throws {
        let chart = try chart()
        XCTAssertEqual(try chart.matchups(defending: ["water"]).map(\.type), PokemonType.allCases)
        XCTAssertEqual(try chart.matchups(defending: ["water", "water"]), try chart.matchups(defending: ["water"]))
        XCTAssertEqual(try chart.matchups(defending: ["water", "flying"]), try chart.matchups(defending: ["flying", "water"]))
        for invalid in [[], ["unknown"], ["water", "unknown"], ["water", "flying", "fire"]] {
            XCTAssertThrowsError(try chart.matchups(defending: invalid))
        }
    }

    func testMalformedChartCannotBecomeNeutralDamage() throws {
        XCTAssertThrowsError(try TypeChart(data: Data("{}".utf8)))
        let bundle = Bundle(for: DexStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "TypeChart", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var invalid = original
        invalid["schemaVersion"] = 2
        XCTAssertThrowsError(try TypeChart(data: JSONSerialization.data(withJSONObject: invalid)))
        invalid = original
        invalid["damageFactors"] = [[100]]
        XCTAssertThrowsError(try TypeChart(data: JSONSerialization.data(withJSONObject: invalid)))
        invalid = original
        var factors = try XCTUnwrap(original["damageFactors"] as? [[Int]])
        factors[0][0] = 300
        invalid["damageFactors"] = factors
        XCTAssertThrowsError(try TypeChart(data: JSONSerialization.data(withJSONObject: invalid)))
    }

    func testAllDualTypesAreCompleteAndIndependentOfOrder() throws {
        let chart = try chart()
        for first in PokemonType.allCases {
            for second in PokemonType.allCases {
                let result = try chart.matchups(defending: [first.rawValue, second.rawValue])
                XCTAssertEqual(result.count, 18)
                XCTAssertEqual(Set(result.map(\.type)).count, 18)
                XCTAssertEqual(result, try chart.matchups(defending: [second.rawValue, first.rawValue]))
            }
        }
    }

    func testReferencePaletteAndNeutralPresentation() {
        XCTAssertEqual(PokemonType.allCases.map(\.abbreviation), "NOR FIR WAT ELE GRA ICE FIG POI GRO FLY PSY BUG ROC GHO DRA DAR STE FAI".split(separator: " ").map(String.init))
        XCTAssertEqual(Set(PokemonType.allCases.map(\.rgb)).count, 18)
        XCTAssertEqual(PokemonType.fire.rgb, 0xFF4422)
        XCTAssertEqual(PokemonType.water.rgb, 0x3399FF)
        XCTAssertEqual(PokemonType.electric.rgb, 0xFFCC33)
        XCTAssertEqual(TypeEffectiveness.neutral.text, "")
        XCTAssertEqual(TypeEffectiveness.neutral.rgb, 0xFFFFFF)
        XCTAssertTrue(TypeEffectiveness.neutral.spokenValue.contains("one times"))
        XCTAssertEqual(TypeEffectiveness.immune.rgb, 0x2E3436)
        XCTAssertEqual(TypeEffectiveness.half.rgb, 0xAA0000)
        XCTAssertEqual(TypeEffectiveness.quarter.rgb, 0x660000)
        XCTAssertEqual(TypeEffectiveness.double.rgb, 0x559900)
        XCTAssertEqual(TypeEffectiveness.quadruple.rgb, 0x77CC00)
    }
}

final class TypeGridLayoutTests: XCTestCase {
    func testFirstFittingArrangementAndExactBoundaries() {
        XCTAssertEqual(TypeGridArrangement.fitting(in: CGSize(width: 284, height: 152)), TypeGridArrangement(rows: 3, columns: 6))
        XCTAssertEqual(TypeGridArrangement.fitting(in: CGSize(width: 428, height: 100)), TypeGridArrangement(rows: 2, columns: 9))
        XCTAssertEqual(TypeGridArrangement.fitting(in: CGSize(width: 140, height: 308)), TypeGridArrangement(rows: 6, columns: 3))
        XCTAssertEqual(TypeGridArrangement.fitting(in: CGSize(width: 92, height: 464)), TypeGridArrangement(rows: 9, columns: 2))
        XCTAssertEqual(TypeGridArrangement.fitting(in: CGSize(width: 1000, height: 1000)), TypeGridArrangement(rows: 3, columns: 6))
        XCTAssertNil(TypeGridArrangement.fitting(in: CGSize(width: 283, height: 152)))
        XCTAssertNil(TypeGridArrangement.fitting(in: .zero))
    }

    func testChosenLayoutsAlwaysContainAllTypesWithoutUndersizedTiles() {
        for width in stride(from: 92, through: 700, by: 19) {
            for height in stride(from: 100, through: 600, by: 17) {
                let size = CGSize(width: width, height: height)
                guard let layout = TypeGridArrangement.fitting(in: size) else { continue }
                XCTAssertEqual(layout.rows * layout.columns, 18)
                XCTAssertGreaterThanOrEqual((size.width - CGFloat(layout.columns - 1) * 4) / CGFloat(layout.columns), 44)
                XCTAssertGreaterThanOrEqual((size.height - CGFloat(layout.rows - 1) * 4) / CGFloat(layout.rows), 48)
            }
        }
    }
}
