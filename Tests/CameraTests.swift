import XCTest
import AVFoundation
import SwiftUI
@testable import DexDuo

private final class TestCameraDriver: CameraDriving {
    let session = AVCaptureSession()
    var failure: CameraFailure?
    var starts = 0, stops = 0, captures = 0
    var rotation: CGFloat?
    var deferredStart = false
    var startResult: CheckedContinuation<AVCaptureDevice?, Error>?
    var photo: CheckedContinuation<UIImage, Error>?
    var interrupted: ((CameraFailure) -> Void)?
    func start(onFailure: @escaping (CameraFailure) -> Void) async throws -> AVCaptureDevice? {
        starts += 1; interrupted = onFailure
        if let failure { throw failure }
        if deferredStart { return try await withCheckedThrowingContinuation { startResult = $0 } }
        return nil
    }
    func stop() { stops += 1 }
    func capture(rotation: CGFloat) async throws -> UIImage {
        captures += 1; self.rotation = rotation
        return try await withCheckedThrowingContinuation { photo = $0 }
    }
}

@MainActor final class CameraTests: XCTestCase {
    private func settle() async { for _ in 0..<20 { await Task.yield() } }
    private func live() async -> (CameraController, TestCameraDriver) {
        let driver = TestCameraDriver()
        // Each test owns its driver; no authorization dialogs or physical camera.
        let owned = CameraController(driver: driver)
        owned.open(); await settle(); XCTAssertEqual(owned.phase, .live)
        return (owned, driver)
    }
    func testPermissionAndUnavailableStatesKeepImportPossible() async {
        for (failure, phase) in [(CameraFailure.denied, CameraPhase.denied), (.unavailable, .unavailable)] {
            let driver = TestCameraDriver(); driver.failure = failure
            let camera = CameraController(driver: driver)
            camera.open(); await settle()
            XCTAssertEqual(camera.phase, phase); XCTAssertNotNil(camera.message)
            driver.failure = nil
            camera.setActive(false); camera.setActive(true); await settle()
            XCTAssertEqual(camera.phase, .live, "Settings changes should be retried on foreground")
            camera.close()
        }
    }
    func testCaptureFreezesAndRetakeResumes() async {
        let (camera, driver) = await live()
        camera.captureRotation = 270
        let capture = Task { await camera.capture() }
        await settle(); XCTAssertEqual(camera.phase, .capturing)
        let duplicate = await camera.capture(); XCTAssertNil(duplicate); XCTAssertEqual(driver.captures, 1)
        let image = UIImage()
        driver.photo?.resume(returning: image)
        let result = await capture.value
        XCTAssertTrue(result === image); XCTAssertEqual(driver.rotation, 270)
        XCTAssertEqual(camera.phase, .frozen)
        camera.setActive(false); camera.setActive(true); await settle()
        XCTAssertEqual(driver.starts, 1, "Captured results must survive foregrounding")
        camera.retake(); await settle(); XCTAssertEqual(camera.phase, .live); XCTAssertEqual(driver.starts, 2)
        camera.close()
    }
    func testImportCancelResumesOnlyPreviouslyLivePreview() async {
        let (camera, driver) = await live()
        camera.beginImport(); XCTAssertEqual(camera.phase, .idle)
        camera.endImport(selected: false); await settle(); XCTAssertEqual(camera.phase, .live)
        camera.beginImport(); camera.endImport(selected: true)
        let starts = driver.starts
        camera.beginImport(); camera.endImport(selected: false); await settle()
        XCTAssertEqual(camera.phase, .frozen); XCTAssertEqual(driver.starts, starts)
        camera.close()
    }
    func testBackgroundAndClosureDiscardLatePhoto() async {
        for close in [false, true] {
            let (camera, driver) = await live()
            let capture = Task { await camera.capture() }; await settle()
            if close { camera.close() } else { camera.setActive(false) }
            driver.photo?.resume(returning: UIImage())
            let result = await capture.value; XCTAssertNil(result)
            camera.setActive(true); await settle()
            XCTAssertEqual(driver.starts, close ? 1 : 2)
            camera.close()
        }
    }
    func testLatePermissionResponseCannotRestartClosedScanner() async {
        let driver = TestCameraDriver(); driver.deferredStart = true
        let camera = CameraController(driver: driver)
        camera.open(); await settle(); XCTAssertEqual(camera.phase, .preparing)
        camera.close(); driver.startResult?.resume(returning: nil); await settle()
        XCTAssertEqual(camera.phase, .idle)
    }
    func testImportSelectionInvalidatesAnAlreadyResumingPreview() async {
        let driver = TestCameraDriver(); driver.deferredStart = true
        let camera = CameraController(driver: driver)
        camera.open(); await settle()
        camera.endImport(selected: true)
        driver.startResult?.resume(returning: nil); await settle()
        XCTAssertEqual(camera.phase, .frozen)
        camera.close()
    }
    func testInterruptionAndStaleError() async {
        let (camera, driver) = await live()
        let old = driver.interrupted
        old?(.interrupted); await settle()
        guard case .failed = camera.phase else { return XCTFail("Interruption should offer Retry") }
        camera.retake(); await settle(); XCTAssertEqual(camera.phase, .live)
        old?(.interrupted); await settle(); XCTAssertEqual(camera.phase, .live)
        camera.close()
    }
    func testFailedCaptureCanRetry() async {
        let (camera, driver) = await live()
        let capture = Task { await camera.capture() }; await settle()
        driver.photo?.resume(throwing: CameraFailure.capture)
        let result = await capture.value; XCTAssertNil(result)
        guard case .failed = camera.phase else { return XCTFail("Capture failure should offer Retry") }
        camera.retake(); await settle(); XCTAssertEqual(camera.phase, .live)
        camera.close()
    }
    func testResetClearsImageCandidatesAndLookupRetry() async {
        let scanner = ScannerModel { _ in RecognitionResult(visual: [], policy: .provisional) }
        scanner.analyze(UIImage(), select: { _ in false }, dismiss: { XCTFail() })
        await settle(); XCTAssertNotNil(scanner.image)
        let label = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
        scanner.choose(label, select: { _ in false }, dismiss: { XCTFail() }); await settle()
        XCTAssertNotNil(scanner.retryCandidate)
        scanner.reset()
        XCTAssertNil(scanner.image); XCTAssertNil(scanner.retryCandidate)
        XCTAssertTrue(scanner.candidates.isEmpty); XCTAssertFalse(scanner.working)
    }
    func testRetakeDuringRecognitionRejectsThePreviousResult() async {
        let (camera, _) = await live()
        camera.beginImport(); camera.endImport(selected: true)
        var result: CheckedContinuation<RecognitionResult, Error>?
        let scanner = ScannerModel { _ in try await withCheckedThrowingContinuation { result = $0 } }
        scanner.analyze(UIImage(), select: { _ in XCTFail("Obsolete scan must not select"); return true }, dismiss: { XCTFail() })
        await settle(); XCTAssertTrue(scanner.working)
        scanner.reset(); camera.retake(); await settle()
        let label = PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")
        var policy = RecognitionPolicy.provisional; policy.automaticLookupEnabled = true
        result?.resume(returning: RecognitionResult(visual: [VisualPrediction(label: label, probability: 0.99)], policy: policy))
        await settle()
        XCTAssertNil(scanner.image); XCTAssertTrue(scanner.candidates.isEmpty)
        XCTAssertEqual(camera.phase, .live); XCTAssertFalse(scanner.working)
        camera.close()
    }
    func testEmbeddedPreviewUsesWholeFrame() async throws {
        let (camera, driver) = await live()
        let host = UIHostingController(rootView: CameraPreview(camera: camera))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 350, height: 230))
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded(); await settle()
        func preview(in view: UIView) -> CameraPreview.PreviewView? {
            if let preview = view as? CameraPreview.PreviewView { return preview }
            return view.subviews.compactMap { preview(in: $0) }.first
        }
        let native = try XCTUnwrap(preview(in: host.view))
        XCTAssertEqual(native.preview.videoGravity, .resizeAspect)
        XCTAssertTrue(native.preview.session === driver.session)
        camera.close(); XCTAssertGreaterThan(driver.stops, 0)
    }
}
