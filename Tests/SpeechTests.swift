import XCTest
import AVFAudio
import UIKit
@testable import DexDuo

private final class FakeSpeechDriver: SpeechDriving {
    var texts: [String] = []
    var events: [@Sendable (SpeechEvent) -> Void] = []
    var stops = 0
    func start(text: String, event: @escaping @Sendable (SpeechEvent) -> Void) { texts.append(text); events.append(event) }
    func stop() { stops += 1 }
}

private actor SpeechFixtureAPI: DexFetching {
    enum Entry { case ready, missing, failed }
    let base: EvolutionFixtureAPI
    var entry = Entry.ready
    init() throws { base = try EvolutionFixtureAPI() }
    func setEntry(_ value: Entry) { entry = value }
    func delay(_ path: String, milliseconds: UInt64) async { await base.delay(path, milliseconds: milliseconds) }
    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        if path.hasPrefix("pokemon?") { return IndexResponse(results: []) as! T }
        if path.hasPrefix("pokemon-species/") {
            if entry == .failed { throw URLError(.notConnectedToInternet) }
            if entry == .missing { return try JSONDecoder().decode(T.self, from: Data(#"{"flavor_text_entries":[]}"#.utf8)) }
        }
        return try await base.get(path == "pokemon/pikachu" ? "pokemon/gastly" : path, as: type)
    }
}

@MainActor final class EntrySpeechTests: XCTestCase {
    private func model(_ driver: FakeSpeechDriver, voiceOver: Bool = false) -> EntrySpeech {
        let defaults = UserDefaults(suiteName: "SpeechTests-\(UUID())")!
        return EntrySpeech(driver: driver, preferences: defaults, voiceOver: { voiceOver })
    }
    private func settle() async { try? await Task.sleep(for: .milliseconds(20)) }

    func testInitialLaunchSilentAndOnlyExplicitReadyEntryReadsFullText() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.start()
        XCTAssertTrue(driver.texts.isEmpty)
        XCTAssertFalse(try XCTUnwrap(store.spokenEntry).automaticallyRead)
        await store.select("haunter")
        XCTAssertEqual(driver.texts, ["Haunter. " + store.entryText])
        XCTAssertEqual(speech.state, .preparing)
        driver.events[0](.started); await settle()
        XCTAssertEqual(speech.state, .speaking)
        XCTAssertEqual(speech.activeEntryID, store.spokenEntry?.id)
    }
    func testPreferencePersistsAndManualReadIgnoresDisabledAutoReadAndVoiceOver() async throws {
        let suite = "SpeechTests-\(UUID())"
        let persisted = UserDefaults(suiteName: suite)!
        defer { persisted.removePersistentDomain(forName: suite) }
        let driver = FakeSpeechDriver()
        let speech = EntrySpeech(driver: driver, preferences: persisted, voiceOver: { true })
        XCTAssertTrue(speech.autoRead)
        speech.autoRead = false
        XCTAssertFalse(EntrySpeech(driver: FakeSpeechDriver(), preferences: persisted).autoRead)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        XCTAssertTrue(driver.texts.isEmpty)
        speech.read(try XCTUnwrap(store.spokenEntry))
        XCTAssertEqual(driver.texts.count, 1)
        speech.autoRead = true
        await store.select("haunter")
        XCTAssertEqual(driver.texts.count, 1, "VoiceOver suppresses automatic speech")
    }
    func testSelectionStopsBeforeFetchAndLatestSuccessfulSelectionWins() async throws {
        let api = try SpeechFixtureAPI(), driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: api)
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        driver.events[0](.started); await settle()
        await api.delay("pokemon/haunter", milliseconds: 100)
        let older = Task { await store.select("haunter") }
        await settle()
        XCTAssertEqual(speech.state, .idle)
        await store.select("gengar")
        _ = await older.value
        driver.events[0](.level(1)); driver.events[0](.finished); await settle()
        XCTAssertEqual(driver.texts.count, 2)
        XCTAssertTrue(driver.texts[1].hasPrefix("Gengar."))
        XCTAssertEqual(speech.state, .preparing)
        XCTAssertEqual(speech.outputLevel, 0)
    }
    func testMissingAndFailedEntriesCannotSpeakPlaceholders() async throws {
        let api = try SpeechFixtureAPI(), driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: api)
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await api.setEntry(.missing); await store.select("gastly")
        XCTAssertNil(store.spokenEntry)
        await api.setEntry(.failed); await store.select("haunter")
        XCTAssertNil(store.spokenEntry)
        XCTAssertTrue(driver.texts.isEmpty)
        await api.setEntry(.ready); await store.select("gengar")
        XCTAssertEqual(store.spokenEntry?.text, store.entryText)
        XCTAssertEqual(driver.texts.count, 1)
    }
    func testStopCoverFoldBackgroundAndScannerRejectLateCallbacksWithoutResume() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        let entry = try XCTUnwrap(store.spokenEntry)
        for context in [(false, true, false), (true, false, false), (true, true, true)] {
            speech.read(entry)
            let callback = driver.events.last!
            callback(.started); callback(.level(0.5)); await settle()
            speech.context(open: context.0, active: context.1, scanning: context.2)
            callback(.started); callback(.level(1)); callback(.failed("Obsolete")); await settle()
            XCTAssertEqual(speech.state, .idle); XCTAssertEqual(speech.outputLevel, 0)
            let count = driver.texts.count
            speech.context(open: true, active: true, scanning: false)
            XCTAssertEqual(driver.texts.count, count)
        }
        speech.read(entry); speech.stop(); driver.events.last?(.started); await settle()
        XCTAssertEqual(speech.state, .idle)
    }
    func testScannerResultWaitsForDismissalAndIsDiscardedOnBackground() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: true)
        await store.select("gastly")
        XCTAssertTrue(driver.texts.isEmpty)
        speech.context(open: true, active: true, scanning: false)
        XCTAssertEqual(driver.texts.count, 1)
        speech.context(open: true, active: true, scanning: true)
        await store.select("haunter")
        speech.context(open: true, active: false, scanning: true)
        speech.context(open: true, active: true, scanning: false)
        XCTAssertEqual(driver.texts.count, 1)
    }
    func testInterruptionAndUnplugStopWithoutAutomaticResume() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        await settle(); XCTAssertEqual(speech.state, .idle)
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
                                        userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        await settle(); XCTAssertEqual(driver.texts.count, 1)
        speech.read(try XCTUnwrap(store.spokenEntry))
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: nil,
                                        userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        await settle(); XCTAssertEqual(speech.state, .idle)
    }
    func testApplicationNotificationsStopDuoEvenIfScenePhaseDoesNotChange() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        await settle(); XCTAssertEqual(speech.state, .idle)
        await store.select("haunter")
        XCTAssertEqual(driver.texts.count, 1)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        await settle(); XCTAssertEqual(speech.state, .idle)
        XCTAssertEqual(driver.texts.count, 1)
        speech.read(try XCTUnwrap(store.spokenEntry))
        XCTAssertEqual(driver.texts.count, 2)
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
        await settle(); XCTAssertEqual(speech.state, .idle)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
        await settle(); XCTAssertEqual(driver.texts.count, 2)
    }
    func testEngineFailureIsActionableAndManualRetryUsesNewToken() async throws {
        let driver = FakeSpeechDriver(), speech = model(driver)
        let store = DexStore(api: try SpeechFixtureAPI())
        speech.observe(store); speech.context(open: true, active: true, scanning: false)
        await store.select("gastly")
        driver.events[0](.failed("Check audio output and tap Read to retry.")); await settle()
        XCTAssertEqual(speech.state, .failed("Check audio output and tap Read to retry."))
        speech.read(try XCTUnwrap(store.spokenEntry))
        driver.events[0](.started); driver.events[0](.level(1)); await settle()
        XCTAssertEqual(speech.state, .preparing); XCTAssertEqual(speech.outputLevel, 0)
        driver.events[1](.started); driver.events[1](.level(0.7)); await settle()
        XCTAssertEqual(speech.state, .speaking); XCTAssertEqual(speech.outputLevel, 0.7)
        driver.events[1](.finished); await settle()
        XCTAssertEqual(speech.state, .idle); XCTAssertNil(speech.activeEntryID)
    }
}

final class RoboticAudioTests: XCTestCase {
    private func buffer(frames: Int) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for channel in 0..<2 { for frame in 0..<frames { buffer.floatChannelData![channel][frame] = 1 } }
        return buffer
    }
    func testModulationHasHeadroomAndPhaseIsContinuousAcrossBuffers() {
        let full = buffer(frames: 4800), first = buffer(frames: 2400), second = buffer(frames: 2400)
        var one = RoboticEffect(), split = RoboticEffect()
        one.process(full); split.process(first); split.process(second)
        let samples = Array(UnsafeBufferPointer(start: full.floatChannelData![0], count: 4800))
        XCTAssertLessThan(samples.min()!, 0.45); XCTAssertLessThanOrEqual(samples.max()!, 0.86)
        XCTAssertGreaterThan(samples.max()! - samples.min()!, 0.4, "Pitch-only playback cannot satisfy this effect")
        for frame in 0..<2400 {
            XCTAssertEqual(full.floatChannelData![0][frame], first.floatChannelData![0][frame])
            XCTAssertEqual(full.floatChannelData![0][frame + 2400], second.floatChannelData![0][frame])
            XCTAssertEqual(full.floatChannelData![0][frame], full.floatChannelData![1][frame])
        }
        let silence = buffer(frames: 240)
        for channel in 0..<2 { silence.floatChannelData![channel].initialize(repeating: 0, count: 240) }
        XCTAssertEqual(RoboticEffect.level(silence), 0)
        XCTAssertGreaterThan(RoboticEffect.level(full), 0)
    }
    func testInstalledVoicePlaysThroughRealEngineAndCleansTemporaryAudio() async throws {
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).filter { $0.hasPrefix("DexDuo-speech-") })
        let driver = SystemSpeechDriver()
        for attempt in 1...2 {
            let started = expectation(description: "Real engine started"), level = expectation(description: "Audible output"), finished = expectation(description: "Completed playback")
            started.assertForOverFulfill = true; level.assertForOverFulfill = false
            let start = ProcessInfo.processInfo.systemUptime
            driver.start(text: "Pikachu. It stores electricity in its cheeks.") { event in
                switch event {
                case .started: print("Speech preparation latency, attempt \(attempt): \(ProcessInfo.processInfo.systemUptime - start) s"); started.fulfill()
                case .level(let value): if value > 0.01 { level.fulfill() }
                case .finished: finished.fulfill()
                case .failed(let message): XCTFail(message); started.fulfill(); level.fulfill(); finished.fulfill()
                }
            }
            await fulfillment(of: [started, level, finished], timeout: 30)
        }
        driver.stop()
        let after = Set(try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).filter { $0.hasPrefix("DexDuo-speech-") })
        XCTAssertEqual(after, before)
    }
    func testRealSynthesisCancellationDiscardsCompletionAndTemporaryAudio() async throws {
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).filter { $0.hasPrefix("DexDuo-speech-") })
        let finished = expectation(description: "Cancelled audio must not finish playback")
        finished.isInverted = true
        let driver = SystemSpeechDriver()
        driver.start(text: String(repeating: "Gastly. Its body is made of gas. ", count: 20)) { event in
            if case .finished = event { finished.fulfill() }
        }
        try await Task.sleep(for: .milliseconds(20)); driver.stop()
        await fulfillment(of: [finished], timeout: 1.5)
        let after = Set(try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()).filter { $0.hasPrefix("DexDuo-speech-") })
        XCTAssertEqual(after, before)
    }
}
