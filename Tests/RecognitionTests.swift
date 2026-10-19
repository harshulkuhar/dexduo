import XCTest
import UIKit
import CoreML
@testable import DexDuo

final class RecognitionTests: XCTestCase {
    let pikachu = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
    let espeon = PokemonLabel(index: 195, speciesID: 196, name: "Espeon", apiName: "espeon")
    var enabled: RecognitionPolicy { RecognitionPolicy(automaticLookupEnabled: true, minimumProbability: 0.9, minimumMargin: 0.2, candidateMinimumProbability: 0.35) }
    func testStableSoftmaxAndRanking() throws {
        let ranked = try RecognitionRules.rank(logits: [1000, 1002], labels: [pikachu, espeon])
        XCTAssertEqual(ranked.first?.label, espeon)
        XCTAssertEqual(ranked.map(\.probability).reduce(0,+), 1, accuracy: 1e-9)
        XCTAssertThrowsError(try RecognitionRules.rank(logits: [.nan], labels: [pikachu]))
        XCTAssertThrowsError(try RecognitionRules.rank(logits: [1], labels: [pikachu, espeon]))
    }
    func testAutomaticThresholds() {
        let high = [VisualPrediction(label: pikachu, probability: 0.95), VisualPrediction(label: espeon, probability: 0.03)]
        XCTAssertEqual(RecognitionRules.decide(visual: high, policy: enabled).automatic, pikachu)
        XCTAssertNil(RecognitionRules.decide(visual: high, policy: .provisional).automatic)
        XCTAssertNil(RecognitionRules.decide(visual: [VisualPrediction(label: pikachu, probability: 0.89)], policy: enabled).automatic)
        var marginPolicy = enabled; marginPolicy.minimumProbability = 0.5
        XCTAssertNil(RecognitionRules.decide(visual: [VisualPrediction(label: pikachu, probability: 0.55), VisualPrediction(label: espeon, probability: 0.45)], policy: marginPolicy).automatic)
    }
    func testNoMatchAndCandidateRanking() {
        let weak = [VisualPrediction(label: pikachu, probability: 0.2)]
        XCTAssertTrue(RecognitionRules.decide(visual: weak, policy: enabled).candidates.isEmpty)
        XCTAssertTrue(RecognitionRules.decide(visual: [], policy: enabled).candidates.isEmpty)
        let uncertain = [VisualPrediction(label: espeon, probability: 0.55), VisualPrediction(label: pikachu, probability: 0.40)]
        let decision = RecognitionRules.decide(visual: uncertain, policy: enabled)
        XCTAssertNil(decision.automatic); XCTAssertEqual(decision.candidates, [espeon, pikachu])
    }
    func testBundledLabelsAndSpecialNames() throws {
        let bundle = Bundle(for: DexStore.self)
        let url = try XCTUnwrap(bundle.url(forResource: "PokemonLabels", withExtension: "json"))
        let labels = try JSONDecoder().decode([PokemonLabel].self, from: Data(contentsOf: url))
        XCTAssertEqual(labels.count, 1025); XCTAssertEqual(Set(labels.map(\.speciesID)).count, 1025)
        XCTAssertEqual(labels.first?.speciesID, 1); XCTAssertEqual(labels.last?.name, "Pecharunt")
        XCTAssertEqual(labels[385].apiName, "deoxys-normal")
        XCTAssertEqual(labels[412].apiName, "wormadam-plant")
        for id in [29,32,83,122,669,772,1025] {
            let label = labels[id-1]
            XCTAssertEqual(label.speciesID, id); XCTAssertFalse(label.apiName.isEmpty)
        }
    }
    func testPreservesWholeImageAndOrientation() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { c in
            UIColor.red.setFill(); c.fill(CGRect(x: 0,y: 0,width: 200,height: 200))
            UIColor.blue.setFill(); c.fill(CGRect(x: 200,y: 0,width: 200,height: 200))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(wide.cgImage), scale: 1, orientation: .right)
        let upright = try ScanImagePreprocessor.upright(rotated)
        XCTAssertEqual(upright.imageOrientation, .up)
        XCTAssertEqual(upright.size, rotated.size)
        let buffer = try ScanImagePreprocessor.buffer(ScanImagePreprocessor.upright(wide))
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 224); XCTAssertEqual(CVPixelBufferGetHeight(buffer), 224)
        CVPixelBufferLockBaseAddress(buffer, .readOnly); defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let row = CVPixelBufferGetBytesPerRow(buffer) * 112
        XCTAssertGreaterThan(bytes[row + 4*10 + 2], 240) // red on left
        XCTAssertGreaterThan(bytes[row + 4*210], 240) // blue on right
    }
    func testGenerationRejectsLateResult() {
        var generation = ScanGeneration(); let old = generation.current
        let fresh = generation.advance()
        XCTAssertFalse(generation.accepts(old)); XCTAssertTrue(generation.accepts(fresh))
    }
}

@MainActor final class ScannerLifecycleTests: XCTestCase {
    func testCancelledInferenceCannotLookUpOrDismiss() async {
        let entered = expectation(description: "recognition entered")
        let finished = expectation(description: "recognition completed")
        var continuation: CheckedContinuation<RecognitionResult, Error>?
        let scanner = ScannerModel { _ in
            let result: RecognitionResult = try await withCheckedThrowingContinuation { continuation = $0; entered.fulfill() }
            finished.fulfill(); return result
        }
        var lookedUp = false, dismissed = false
        scanner.analyze(UIImage(), select: { _ in lookedUp = true; return true }, dismiss: { dismissed = true })
        await fulfillment(of: [entered], timeout: 2)
        scanner.cancel()
        let label = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
        var policy = RecognitionPolicy.provisional; policy.automaticLookupEnabled = true
        continuation?.resume(returning: RecognitionResult(visual: [VisualPrediction(label: label, probability: 0.99)], policy: policy))
        await fulfillment(of: [finished], timeout: 2)
        await Task.yield()
        XCTAssertFalse(lookedUp); XCTAssertFalse(dismissed); XCTAssertFalse(scanner.working)
    }
    func testFailedLookupRetainsCandidateAndRetrySucceeds() async {
        let scanner = ScannerModel()
        let label = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
        let failed = expectation(description: "failed request")
        var dismissed = false
        scanner.choose(label, select: { _ in failed.fulfill(); return false }, dismiss: { dismissed = true })
        await fulfillment(of: [failed], timeout: 2); await Task.yield()
        XCTAssertEqual(scanner.retryCandidate, label); XCTAssertFalse(dismissed)
        let success = expectation(description: "dismissed on success")
        scanner.choose(label, select: { _ in true }, dismiss: { dismissed = true; success.fulfill() })
        await fulfillment(of: [success], timeout: 2)
        XCTAssertTrue(dismissed); XCTAssertNil(scanner.retryCandidate)
    }
    func testDuplicateChoiceStartsOnlyOneLookup() async {
        let scanner = ScannerModel()
        let label = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
        let entered = expectation(description: "lookup")
        var calls = 0
        var continuation: CheckedContinuation<Bool, Never>?
        let lookup: (String) async -> Bool = { _ in calls += 1; return await withCheckedContinuation { continuation = $0; entered.fulfill() } }
        scanner.choose(label, select: lookup, dismiss: {})
        scanner.choose(label, select: lookup, dismiss: {})
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(calls, 1)
        scanner.cancel(); continuation?.resume(returning: true)
    }
}

private struct FailingAPI: DexFetching {
    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T { throw URLError(.notConnectedToInternet) }
}
@MainActor final class LookupTests: XCTestCase {
    func testFailedSelectionReturnsFalseAndLeavesPreviousEntry() async {
        let store = DexStore(api: FailingAPI())
        let success = await store.select("pikachu")
        XCTAssertFalse(success)
        XCTAssertNotNil(store.error); XCTAssertFalse(store.loading); XCTAssertNil(store.pokemon)
    }
}

final class ModelIntegrationTests: XCTestCase {
    func testOfflineArtworkRecognitionUsesBundledModel() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "espeon", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let result = try await PokemonRecognitionService.shared.recognize(image)
        XCTAssertEqual(result.visual.first?.label.speciesID, 196)
        XCTAssertGreaterThan(result.visual.first?.probability ?? 0, 0.9)
    }
    func testImageWithoutTextCanClassifyPikachu() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "pikachu", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let result = try await PokemonRecognitionService.shared.recognize(image)
        XCTAssertEqual(result.visual.first?.label.speciesID, 25)
    }
}
