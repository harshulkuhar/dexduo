import Foundation

enum PokemonType: String, Decodable, CaseIterable {
    case normal, fire, water, electric, grass, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    var title: String { rawValue.capitalized }
    var abbreviation: String { String(rawValue.prefix(3)).uppercased() }

    var rgb: UInt32 {
        switch self {
        case .normal: return 0xAAAA99
        case .fire: return 0xFF4422
        case .water: return 0x3399FF
        case .electric: return 0xFFCC33
        case .grass: return 0x77CC55
        case .ice: return 0x66CCFF
        case .fighting: return 0xBB5544
        case .poison: return 0xAA5599
        case .ground: return 0xDDBB55
        case .flying: return 0x8899FF
        case .psychic: return 0xFF5599
        case .bug: return 0xAABB22
        case .rock: return 0xBBAA66
        case .ghost: return 0x6666BB
        case .dragon: return 0x7766EE
        case .dark: return 0x775544
        case .steel: return 0xAAAABB
        case .fairy: return 0xEE99EE
        }
    }
}

enum TypeEffectiveness: Double {
    case immune = 0, quarter = 0.25, half = 0.5, neutral = 1, double = 2, quadruple = 4

    var text: String {
        switch self {
        case .immune: return "0×"
        case .quarter: return "¼×"
        case .half: return "½×"
        case .neutral: return ""
        case .double: return "2×"
        case .quadruple: return "4×"
        }
    }

    var spokenValue: String {
        switch self {
        case .immune: return "immune, zero damage"
        case .quarter: return "one quarter damage"
        case .half: return "half damage"
        case .neutral: return "neutral, one times damage"
        case .double: return "two times damage"
        case .quadruple: return "four times damage"
        }
    }

    var rgb: UInt32 {
        switch self {
        case .immune: return 0x2E3436
        case .quarter: return 0x660000
        case .half: return 0xAA0000
        case .neutral: return 0xFFFFFF
        case .double: return 0x559900
        case .quadruple: return 0x77CC00
        }
    }
}

struct TypeMatchup: Equatable {
    let type: PokemonType
    let effectiveness: TypeEffectiveness
}

struct TypeChart {
    private struct Snapshot: Decodable {
        let schemaVersion: Int
        let types: [PokemonType]
        let damageFactors: [[Int]]
    }

    static let bundled = Result { try TypeChart.load() }
    private let factors: [[Int]]

    init(data: Data) throws {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard snapshot.schemaVersion == 1, snapshot.types == PokemonType.allCases,
              snapshot.damageFactors.count == 18,
              snapshot.damageFactors.allSatisfy({ $0.count == 18 && $0.allSatisfy { [0, 50, 100, 200].contains($0) } }) else {
            throw TypeChartError.invalidChart
        }
        factors = snapshot.damageFactors
    }

    static func load(bundle: Bundle = .main) throws -> TypeChart {
        guard let url = bundle.url(forResource: "TypeChart", withExtension: "json") else {
            throw TypeChartError.invalidChart
        }
        return try TypeChart(data: Data(contentsOf: url))
    }

    func matchups(defending names: [String]) throws -> [TypeMatchup] {
        let unique = Set(names)
        let types = PokemonType.allCases
        let indices = unique.compactMap { name in types.firstIndex { $0.rawValue == name } }
        guard (1...2).contains(unique.count), indices.count == unique.count else {
            throw TypeChartError.invalidDefendingTypes
        }
        return try types.enumerated().map { attacker, type in
            let multiplier = indices.reduce(1.0) { $0 * Double(factors[attacker][$1]) / 100 }
            guard let effectiveness = TypeEffectiveness(rawValue: multiplier) else { throw TypeChartError.invalidChart }
            return TypeMatchup(type: type, effectiveness: effectiveness)
        }
    }
}

enum TypeChartError: Error {
    case invalidChart, invalidDefendingTypes
}

struct TypeGridArrangement: Equatable {
    let rows: Int
    let columns: Int
    static let gap: CGFloat = 4
    static let minimumTileSize = CGSize(width: 44, height: 48)

    static func fitting(in size: CGSize) -> TypeGridArrangement? {
        for (rows, columns) in [(3, 6), (2, 9), (6, 3), (9, 2)] {
            let width = CGFloat(columns) * minimumTileSize.width + CGFloat(columns - 1) * gap
            let height = CGFloat(rows) * minimumTileSize.height + CGFloat(rows - 1) * gap
            if size.width >= width && size.height >= height {
                return TypeGridArrangement(rows: rows, columns: columns)
            }
        }
        return nil
    }
}
