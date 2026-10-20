import AVFAudio

/// Native audio objects and sample processing stay on the serial audio queue.
/// The callback's PCM handoff is bounded and protected by a lock.
/// PCM is spooled to a temporary file, then read in 100 ms blocks with at most
/// two seconds scheduled. Long entries do not accumulate decoded audio in RAM.
final class SystemSpeechDriver: SpeechDriving, @unchecked Sendable {
    private let queue = DispatchQueue(label: "DexDuo.speech", qos: .default)
    private var run: SpeechRun?
    private let lock = NSLock()
    private var cancellation: SpeechCancellation?
    func start(text: String, event: @escaping @Sendable (SpeechEvent) -> Void) {
        let token = SpeechCancellation()
        lock.lock(); cancellation?.cancel(); cancellation = token; lock.unlock()
        queue.async { [self] in
            run?.stop()
            guard !token.cancelled else { run = nil; return }
            let next = SpeechRun(queue: queue, cancellation: token, event: event)
            run = next
            next.start(text)
        }
    }
    func stop() {
        lock.lock(); cancellation?.cancel(); lock.unlock()
        queue.async { [self] in run?.stop(); run = nil }
    }
}

private final class SpeechCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func cancel() { lock.lock(); value = true; lock.unlock() }
}

/// A fresh envelope belongs to each playback run and is advanced only by mixer samples.
struct SpeechLevelEnvelope {
    private(set) var value: Float = 0
    mutating func advance(target: Float, elapsed: TimeInterval) -> Float {
        guard elapsed.isFinite, elapsed > 0 else { return value }
        let target = target.isFinite ? min(1, max(0, target)) : 0
        let timeConstant = target > value ? 0.040 : 0.120
        value += (target - value) * Float(1 - exp(-elapsed / timeConstant))
        if target == 0 && value < 0.0001 { value = 0 }
        return value
    }
}

struct RoboticEffect {
    private var phase: Double = 0
    mutating func process(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let increment = 2 * Double.pi * 70 / buffer.format.sampleRate
        for frame in 0..<Int(buffer.frameLength) {
            let gain = Float(0.75 + 0.25 * sin(phase)) * 0.85
            for channel in 0..<Int(buffer.format.channelCount) {
                channels[channel][frame] = max(-1, min(1, channels[channel][frame] * gain))
            }
            phase = (phase + increment).truncatingRemainder(dividingBy: 2 * .pi)
        }
    }
    static func level(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) { let value = channels[channel][frame]; sum += value * value }
        }
        return min(1, sqrt(sum / Float(buffer.frameLength * buffer.format.channelCount)) * 4)
    }
}

private final class SpeechRun: @unchecked Sendable {
    private let queue: DispatchQueue
    private let cancellation: SpeechCancellation
    private let bufferLock = NSLock()
    private var pendingDuration: Double = 0
    private let event: @Sendable (SpeechEvent) -> Void
    private let url = FileManager.default.temporaryDirectory.appendingPathComponent("DexDuo-speech-\(UUID()).caf")
    private var synthesizer: AVSpeechSynthesizer?
    private var writer: AVAudioFile?
    private var reader: AVAudioFile?
    private var engine: AVAudioEngine?
    private let player = AVAudioPlayerNode()
    private var effect = RoboticEffect()
    private var stopped = false
    private var synthesized = false
    private var tapped = false
    private var sessionActive = false
    private var queued = 0
    private var configurationObserver: NSObjectProtocol?

    init(queue: DispatchQueue, cancellation: SpeechCancellation, event: @escaping @Sendable (SpeechEvent) -> Void) {
        self.queue = queue; self.cancellation = cancellation; self.event = event
    }
    func start(_ text: String) {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        guard let voice = voices.first(where: { $0.language == "en-US" && $0.quality == .default })
                ?? voices.first(where: { $0.language == "en-US" }) ?? voices.first else {
            fail("No English voice is installed. Add an English voice in Settings → Accessibility → Spoken Content, then tap Read."); return
        }
        let synth = AVSpeechSynthesizer(); synthesizer = synth
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice; utterance.rate = 0.46; utterance.pitchMultiplier = 0.88
        synth.write(utterance) { [weak self] buffer in
            self?.enqueue(buffer)
        }
        queue.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, !self.stopped, !self.synthesized else { return }
            self.fail("The voice didn’t finish preparing. Check installed English voices and tap Read to retry.")
        }
    }
    private func enqueue(_ buffer: AVAudioBuffer) {
        // Native callbacks can arrive on the main thread. Copy borrowed PCM,
        // then return without synchronously executing audio work on that thread.
        guard !cancellation.cancelled, let pcm = buffer as? AVAudioPCMBuffer else { return }
        if pcm.frameLength == 0 { queue.async { [self] in receive(nil) }; return }
        let duration = Double(pcm.frameLength) / pcm.format.sampleRate
        bufferLock.lock()
        let fits = pendingDuration + duration <= 2
        if fits { pendingDuration += duration }
        bufferLock.unlock()
        guard fits, let copy = AVAudioPCMBuffer(pcmFormat: pcm.format, frameCapacity: pcm.frameLength) else {
            cancellation.cancel()
            queue.async { [self] in fail("Audio preparation fell behind. Tap Read to retry.") }
            return
        }
        copy.frameLength = pcm.frameLength
        let source = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<source.count {
            if let from = source[index].mData, let to = destination[index].mData { memcpy(to, from, Int(destination[index].mDataByteSize)) }
        }
        queue.async { [self] in
            receive(copy)
            bufferLock.lock(); pendingDuration -= duration; bufferLock.unlock()
        }
    }
    private func receive(_ pcm: AVAudioPCMBuffer?) {
        guard !stopped, !cancellation.cancelled, !synthesized else { return }
        do {
            if let pcm {
                if writer == nil {
                    writer = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                                             commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
                }
                try writer?.write(from: pcm)
            } else {
                synthesized = true; writer = nil
                try play()
            }
        } catch { fail("Audio couldn’t start. Check your audio output, then tap Read to retry.") }
    }
    private func play() throws {
        guard !cancellation.cancelled else { stop(); return }
        reader = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let reader, reader.length > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true); sessionActive = true
        guard !cancellation.cancelled else { stop(); return }
        let engine = AVAudioEngine()
        self.engine = engine
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: reader.processingFormat)
        var lastReport: TimeInterval = 0
        var envelope = SpeechLevelEnvelope()
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [event, cancellation] buffer, _ in
            guard !cancellation.cancelled else { return }
            let level = envelope.advance(target: RoboticEffect.level(buffer),
                                         elapsed: Double(buffer.frameLength) / buffer.format.sampleRate)
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastReport >= 1.0 / 30 {
                lastReport = now; event(.level(level))
            }
        }
        tapped = true
        try engine.start()
        guard !cancellation.cancelled else { stop(); return }
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                if !self.stopped { self.fail("Audio output changed. Check your output and tap Read to retry.") }
            }
        }
        try fillQueue()
        guard !cancellation.cancelled else { stop(); return }
        player.play(); event(.started)
    }
    private func fillQueue() throws {
        guard !stopped, !cancellation.cancelled, let reader else { return }
        let frames = AVAudioFrameCount(reader.processingFormat.sampleRate / 10)
        while queued < 20 && reader.framePosition < reader.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: frames) else { throw CocoaError(.coderInvalidValue) }
            try reader.read(into: buffer)
            effect.process(buffer); queued += 1
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard !self.stopped, !self.cancellation.cancelled else { return }
                    self.queued -= 1
                    do {
                        try self.fillQueue()
                        if self.queued == 0 { self.stop(); self.event(.finished) }
                    } catch { self.fail("Audio playback stopped. Check your audio output, then tap Read to retry.") }
                }
            }
        }
    }
    private func fail(_ message: String) { stop(); event(.failed(message)) }
    func stop() {
        guard !stopped else { return }
        stopped = true
        cancellation.cancel()
        if let observer = configurationObserver { NotificationCenter.default.removeObserver(observer); configurationObserver = nil }
        synthesizer?.stopSpeaking(at: .immediate); synthesizer = nil
        player.stop()
        if let engine {
            if tapped { engine.mainMixerNode.removeTap(onBus: 0); tapped = false }
            engine.stop()
        }
        engine = nil; reader = nil; writer = nil
        try? FileManager.default.removeItem(at: url)
        if sessionActive { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation); sessionActive = false }
    }
}
