import AVFAudio
import Combine
import UIKit

struct SpokenEntry {
    let id: UUID
    let name: String
    let text: String
    let automaticallyRead: Bool
    var utterance: String { "\(name). \(text)" }
}

enum SpeechState: Equatable {
    case idle, preparing, speaking, failed(String)
    var active: Bool { self == .preparing || self == .speaking }
}

enum SpeechEvent { case started, level(Float), finished, failed(String) }

protocol SpeechDriving: AnyObject {
    func start(text: String, event: @escaping @Sendable (SpeechEvent) -> Void)
    func stop()
}

@MainActor final class EntrySpeech: ObservableObject {
    @Published private(set) var state = SpeechState.idle
    @Published private(set) var activeEntryID: UUID?
    @Published private(set) var outputLevel: Float = 0
    @Published var autoRead: Bool {
        didSet { preferences.set(autoRead, forKey: Self.preferenceKey); if !autoRead { pending = nil } }
    }
    static let preferenceKey = "DexDuoAutoRead"
    private let driver: any SpeechDriving
    private let preferences: UserDefaults
    private let voiceOver: @MainActor () -> Bool
    private var subscriptions: Set<AnyCancellable> = []
    private var storeSubscriptions: Set<AnyCancellable> = []
    private var generation = UUID()
    private var open = false
    private var active = false
    private var scanning = false
    private var pending: SpokenEntry?

    init(driver: any SpeechDriving = SystemSpeechDriver(), preferences: UserDefaults = .standard,
         voiceOver: @escaping @MainActor () -> Bool = { UIAccessibility.isVoiceOverRunning }) {
        self.driver = driver; self.preferences = preferences; self.voiceOver = voiceOver
        autoRead = preferences.object(forKey: Self.preferenceKey) == nil ? true : preferences.bool(forKey: Self.preferenceKey)
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification,
                     UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification] {
            NotificationCenter.default.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                self?.active = false; self?.stop()
            }.store(in: &subscriptions)
        }
        for name in [UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification] {
            NotificationCenter.default.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in self?.active = true }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main).sink { [weak self] note in
            if note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue { self?.stop() }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main).sink { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  [.oldDeviceUnavailable, .newDeviceAvailable, .noSuitableRouteForCategory].contains(reason) else { return }
            self?.stop()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification).receive(on: RunLoop.main).sink { [weak self] _ in self?.stop() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification).receive(on: RunLoop.main).sink { [weak self] _ in self?.stop() }.store(in: &subscriptions)
    }

    func observe(_ store: DexStore) {
        storeSubscriptions.removeAll()
        store.selectionBegan.sink { [weak self] in self?.stop() }.store(in: &storeSubscriptions)
        // Attaching/reopening a scene must never narrate an existing selection.
        store.$spokenEntry.dropFirst().sink { [weak self] entry in
            guard let self, let entry, entry.automaticallyRead, self.autoRead, !self.voiceOver(), self.open, self.active else { return }
            if self.scanning { self.pending = entry } else { self.read(entry) }
        }.store(in: &storeSubscriptions)
    }

    func context(open: Bool, active: Bool, scanning: Bool) {
        let wasScanning = self.scanning
        self.open = open; self.active = active; self.scanning = scanning
        if !open || !active || scanning { stop() }
        else if wasScanning, let entry = pending {
            pending = nil
            if autoRead && !voiceOver() { read(entry) }
        }
    }

    func read(_ entry: SpokenEntry) {
        guard open, active, !scanning, !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()
        let token = generation
        activeEntryID = entry.id; state = .preparing
        driver.start(text: entry.utterance) { [weak self] event in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                switch event {
                case .started: self.state = .speaking
                case .level(let value):
                    guard self.state == .speaking else { return }
                    self.outputLevel = value.isFinite ? min(1, max(0, value)) : 0
                case .finished: self.stop()
                case .failed(let message): self.stop(); self.state = .failed(message)
                }
            }
        }
    }

    func stop() {
        generation = UUID(); pending = nil; driver.stop()
        state = .idle; activeEntryID = nil; outputLevel = 0
    }
}
