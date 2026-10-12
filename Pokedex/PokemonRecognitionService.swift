import CoreML
import UIKit
import SwiftUI

enum ScanImagePreprocessor {
    /// Drawing UIImage applies its EXIF orientation, preserving the whole image.
    static func upright(_ image: UIImage, maxDimension: CGFloat = 1800) throws -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { throw RecognitionError.invalidImage }
        let factor = min(1, maxDimension / max(image.size.width, image.size.height))
        return draw(image, size: CGSize(width: image.size.width * factor, height: image.size.height * factor))
    }
    private static func draw(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.interpolationQuality = .low // bilinear interpolation
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    static func buffer(_ upright: UIImage) throws -> CVPixelBuffer {
        let resized = draw(upright, size: CGSize(width: 224, height: 224))
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true,
                                          kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        guard CVPixelBufferCreate(kCFAllocatorDefault, 224, 224, kCVPixelFormatType_32BGRA,
                                  attributes as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else {
            throw RecognitionError.invalidImage
        }
        CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 224, height: 224,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
              let cgImage = resized.cgImage else { throw RecognitionError.invalidImage }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 224, height: 224))
        return buffer
    }
}

/// Actor methods perform synchronous native work on the actor executor, keeping
/// one model alive and serializing predictions away from the main actor.
actor PokemonRecognitionService {
    static let shared = PokemonRecognitionService()
    private var model: MLModel?
    private var labels: [PokemonLabel]?
    private let bundle: Bundle
    init(bundle: Bundle = .main) { self.bundle = bundle }

    private func loadLabels() throws -> [PokemonLabel] {
        if let labels { return labels }
        guard let url = bundle.url(forResource: "PokemonLabels", withExtension: "json"),
              let entries = try? JSONDecoder().decode([PokemonLabel].self, from: Data(contentsOf: url)),
              entries.count == 1025, entries.enumerated().allSatisfy({ $0.offset == $0.element.index }),
              Set(entries.map(\.speciesID)).count == 1025 else { throw RecognitionError.invalidLabels }
        labels = entries; return entries
    }
    private func loadModel() throws -> MLModel {
        if let model { return model }
        guard let url = bundle.url(forResource: "PokemonClassifier", withExtension: "mlmodelc") else { throw RecognitionError.modelUnavailable }
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        // This Duo runtime's GPU backend reports incompatible MPSGraph state
        // and can return zero logits. CPU inference remains fully local.
        configuration.computeUnits = .cpuOnly
        #else
        configuration.computeUnits = .all
        #endif
        do { let loaded = try MLModel(contentsOf: url, configuration: configuration); model = loaded; return loaded }
        catch { throw RecognitionError.modelUnavailable }
    }
    private func policy() -> RecognitionPolicy {
        struct Manifest: Decodable { let policy: RecognitionPolicy }
        guard let url = bundle.url(forResource: "ModelManifest", withExtension: "json"),
              let data = try? Data(contentsOf: url), let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
            return .provisional
        }
        var policy = manifest.policy
        #if DEBUG
        // Exercise the confirmation UI with the real model in simulator tests.
        if ProcessInfo.processInfo.arguments.contains("--confirm-scans") { policy.automaticLookupEnabled = false }
        #endif
        return policy
    }
    private func predict(_ model: MLModel, input: MLFeatureProvider) throws -> MLFeatureProvider {
        do { return try model.prediction(from: input) }
        catch { throw RecognitionError.invalidOutput }
    }
    func recognize(_ image: UIImage) async throws -> RecognitionResult {
        try Task.checkCancellation()
        let entries = try loadLabels()
        let upright = try ScanImagePreprocessor.upright(image)
        let loaded = try loadModel()
        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: ScanImagePreprocessor.buffer(upright))])
        let output = try predict(loaded, input: input)
        guard let logits = output.featureValue(for: "logits")?.multiArrayValue else { throw RecognitionError.invalidOutput }
        let visual = try RecognitionRules.rank(logits: (0..<logits.count).map { logits[$0].doubleValue }, labels: entries)
        try Task.checkCancellation()
        return RecognitionResult(visual: visual, policy: policy())

    }
}

@MainActor final class ScannerModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var working = false
    @Published private(set) var message = "Capture or import an image of one Pokémon or card."
    @Published private(set) var candidates: [PokemonLabel] = []
    @Published private(set) var retryCandidate: PokemonLabel?
    private var generation = ScanGeneration()
    private var task: Task<Void, Never>?
    private let recognize: (UIImage) async throws -> RecognitionResult
    init(recognize: @escaping (UIImage) async throws -> RecognitionResult = { try await PokemonRecognitionService.shared.recognize($0) }) {
        self.recognize = recognize
    }
    func cancel() { _ = generation.advance(); task?.cancel(); task = nil; working = false }
    func showMessage(_ value: String) { message = value }
    func analyze(_ image: UIImage, select: @escaping (String) async -> Bool, dismiss: @escaping () -> Void) {
        cancel(); let token = generation.current
        self.image = image; candidates = []; retryCandidate = nil; working = true; message = "Identifying Pokémon…"
        task = Task {
            do {
                let result = try await recognize(image)
                guard !Task.isCancelled, generation.accepts(token) else { return }
                let decision = RecognitionRules.decide(visual: result.visual, policy: result.policy)
                candidates = decision.candidates
                if let automatic = decision.automatic {
                    await lookup(automatic, token: token, select: select, dismiss: dismiss)
                } else {
                    working = false
                    message = candidates.isEmpty ? "Couldn’t identify a Pokémon. Try a closer image or use search." : "Choose the Pokémon that matches your image."
                }
            } catch {
                guard !Task.isCancelled, generation.accepts(token) else { return }
                working = false; message = error.localizedDescription
            }
        }
    }
    func choose(_ candidate: PokemonLabel, select: @escaping (String) async -> Bool, dismiss: @escaping () -> Void) {
        guard !working else { return }
        let token = generation.current; working = true
        task = Task { await lookup(candidate, token: token, select: select, dismiss: dismiss) }
    }
    private func lookup(_ candidate: PokemonLabel, token: UUID, select: (String) async -> Bool, dismiss: () -> Void) async {
        message = "Loading \(candidate.name)…"
        let success = await select(candidate.apiName)
        guard !Task.isCancelled, generation.accepts(token) else { return }
        working = false
        if success { retryCandidate = nil; dismiss() }
        else { retryCandidate = candidate; message = "Couldn’t load \(candidate.name)’s Pokédex data. Check your connection and retry." }
    }
}
