import Foundation

struct PokemonLabel: Decodable, Identifiable, Equatable {
    let index: Int
    let speciesID: Int
    let name: String
    let apiName: String
    var id: Int { speciesID }
}

struct VisualPrediction {
    let label: PokemonLabel
    let probability: Double
}

struct RecognitionPolicy: Decodable {
    var automaticLookupEnabled: Bool
    var minimumProbability: Double
    var minimumMargin: Double
    var candidateMinimumProbability: Double
    static let provisional = RecognitionPolicy(automaticLookupEnabled: false, minimumProbability: 0.9,
                                              minimumMargin: 0.2, candidateMinimumProbability: 0.35)
}

struct ScanDecision {
    let candidates: [PokemonLabel]
    let automatic: PokemonLabel?
}

enum RecognitionRules {
    static func rank(logits: [Double], labels: [PokemonLabel]) throws -> [VisualPrediction] {
        guard logits.count == labels.count, !logits.isEmpty, logits.allSatisfy(\.isFinite) else {
            throw RecognitionError.invalidOutput
        }
        let largest = logits.max()!
        let weights = logits.map { exp($0 - largest) }
        let total = weights.reduce(0, +)
        return zip(labels, weights).map { VisualPrediction(label: $0.0, probability: $0.1 / total) }
            .sorted { $0.probability == $1.probability ? $0.label.index < $1.label.index : $0.probability > $1.probability }
    }

    static func decide(visual: [VisualPrediction], policy: RecognitionPolicy) -> ScanDecision {
        guard let best = visual.first else { return ScanDecision(candidates: [], automatic: nil) }
        let margin = best.probability - (visual.dropFirst().first?.probability ?? 0)
        let automatic = policy.automaticLookupEnabled && best.probability >= policy.minimumProbability && margin >= policy.minimumMargin
            ? best.label : nil
        let candidates = best.probability >= policy.candidateMinimumProbability ? Array(visual.prefix(3).map(\.label)) : []
        return ScanDecision(candidates: candidates, automatic: automatic)
    }

}

enum RecognitionError: Error, LocalizedError {
    case modelUnavailable, invalidImage, invalidOutput, invalidLabels
    var errorDescription: String? {
        switch self {
        case .modelUnavailable: return "Artwork recognition is unavailable. Please try again."
        case .invalidImage: return "Couldn’t open this image. Please try another."
        case .invalidOutput: return "Couldn’t classify this image. Please try another."
        case .invalidLabels: return "The bundled Pokémon labels could not be loaded."
        }
    }
}

struct RecognitionResult {
    let visual: [VisualPrediction]
    let policy: RecognitionPolicy
}

/// Token ownership is independent of cooperative cancellation: native inference
/// cannot always be interrupted, so late completions must never update the UI.
struct ScanGeneration {
    private(set) var current = UUID()
    mutating func advance() -> UUID { current = UUID(); return current }
    func accepts(_ token: UUID) -> Bool { token == current }
}
