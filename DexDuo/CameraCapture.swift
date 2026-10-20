@preconcurrency import AVFoundation
import SwiftUI

enum CameraFailure: Error, LocalizedError {
    case unavailable, denied, configuration, capture, interrupted

    var errorDescription: String? {
        switch self {
        case .unavailable: return "The Simulator has no camera. Use Import to test a card photo or screenshot."
        case .denied: return "Camera access is off. Enable it for DexDuo in Settings, or import a photo."
        case .configuration: return "Couldn’t start the rear camera. Retry or import a photo."
        case .capture: return "Couldn’t capture this photo. Retry or import a photo."
        case .interrupted: return "The camera was interrupted. Retry or import a photo."
        }
    }
}

enum CameraPhase: Equatable {
    case idle, preparing, live, capturing, frozen, denied, unavailable, failed(String)
}

protocol CameraDriving: AnyObject {
    var session: AVCaptureSession { get }
    func start(onFailure: @escaping (CameraFailure) -> Void) async throws -> AVCaptureDevice?
    func stop()
    func detachPreview(_ layer: AVCaptureVideoPreviewLayer)
    func capture(rotation: CGFloat) async throws -> UIImage
}

/// All session configuration, start/stop and photo requests stay on this queue.
final class NativeCameraDriver: CameraDriving, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue: DispatchQueue
    private var run: UUID?
    private var onFailure: ((CameraFailure) -> Void)?
    private var receivers: [Int64: PhotoReceiver] = [:]
    private var observers: [NSObjectProtocol] = []

    init(queue: DispatchQueue = DispatchQueue(label: "com.harshulkuhar.dexduo.camera")) {
        self.queue = queue
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard self.run != nil else { return }
                    self.onFailure?(.interrupted)
                }
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func start(onFailure: @escaping (CameraFailure) -> Void) async throws -> AVCaptureDevice? {
        let token = UUID()
        // Enqueue before requesting permission, so stop() also invalidates a pending prompt.
        let device: AVCaptureDevice = try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                run = token; self.onFailure = onFailure
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    continuation.resume(throwing: CameraFailure.unavailable); return
                }
                continuation.resume(returning: device)
            }
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard run == token else { continuation.resume(throwing: CancellationError()); return }
                guard allowed else { continuation.resume(throwing: CameraFailure.denied); return }
                do {
                    if session.inputs.isEmpty {
                        session.beginConfiguration()
                        defer { session.commitConfiguration() }
                        session.sessionPreset = .photo
                        let input = try AVCaptureDeviceInput(device: device)
                        guard session.canAddInput(input), session.canAddOutput(output) else { throw CameraFailure.configuration }
                        session.addInput(input); session.addOutput(output)
                        output.maxPhotoQualityPrioritization = .balanced
                    }
                    session.startRunning()
                    guard session.isRunning else { throw CameraFailure.configuration }
                    continuation.resume(returning: device)
                } catch { continuation.resume(throwing: CameraFailure.configuration) }
            }
        }
    }

    func stop() {
        queue.async { [self] in
            run = nil; onFailure = nil
            receivers.values.forEach { $0.finish(.failure(CancellationError())) }
            if session.isRunning { session.stopRunning() }
        }
    }

    func detachPreview(_ layer: AVCaptureVideoPreviewLayer) {
        // Disconnecting also changes the session graph and can wait for stopRunning.
        // Retain the layer until that work finishes, so dismissal never does it on main.
        nonisolated(unsafe) let detachedLayer = layer
        queue.async { detachedLayer.session = nil }
    }

    func capture(rotation: CGFloat) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard run != nil, session.isRunning, let connection = output.connection(with: .video) else {
                    continuation.resume(throwing: CameraFailure.capture); return
                }
                guard connection.isVideoRotationAngleSupported(rotation) else {
                    continuation.resume(throwing: CameraFailure.capture); return
                }
                connection.videoRotationAngle = rotation
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .balanced
                let receiver = PhotoReceiver(continuation: continuation) { [weak self] id in
                    guard let self else { return }
                    self.queue.async { self.receivers[id] = nil }
                }
                receivers[settings.uniqueID] = receiver
                output.capturePhoto(with: settings, delegate: receiver)
            }
        }
    }

    private final class PhotoReceiver: NSObject, AVCapturePhotoCaptureDelegate {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<UIImage, Error>?
        private let completed: (Int64) -> Void
        init(continuation: CheckedContinuation<UIImage, Error>, completed: @escaping (Int64) -> Void) {
            self.continuation = continuation; self.completed = completed
        }
        func finish(_ result: Result<UIImage, Error>) {
            lock.lock(); let pending = continuation; continuation = nil; lock.unlock()
            pending?.resume(with: result)
        }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
                finish(.failure(CameraFailure.capture)); return
            }
            finish(.success(image))
        }
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
            if error != nil { finish(.failure(CameraFailure.capture)) }
            completed(resolvedSettings.uniqueID)
        }
    }
}

@MainActor final class CameraController: ObservableObject {
    @Published private(set) var phase = CameraPhase.idle
    @Published private(set) var device: AVCaptureDevice?
    let driver: CameraDriving
    var captureRotation: CGFloat = 0
    private var generation = ScanGeneration()
    private var visible = false
    private var active = true
    private var importing = false
    private var wantsLive = true
    private var task: Task<Void, Never>?

    init(driver: CameraDriving = NativeCameraDriver()) { self.driver = driver }
    func open() { visible = true; resume() }
    func close() { visible = false; pause() }
    func setActive(_ value: Bool) { active = value; if value { resume() } else { pause() } }
    func beginImport() { importing = true; pause() }
    func endImport(selected: Bool) {
        importing = false
        if selected { wantsLive = false; pause(); phase = .frozen } else { resume() }
    }
    func retake() { wantsLive = true; resume() }
    private func pause() {
        _ = generation.advance(); task?.cancel(); task = nil; driver.stop()
        if wantsLive { phase = .idle }
    }
    private func resume() {
        guard visible, active, !importing, wantsLive, phase != .live, phase != .preparing else { return }
        pause(); phase = .preparing
        let token = generation.current
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let device = try await self.driver.start { [weak self] error in
                    Task { @MainActor in
                        guard let self, self.generation.accepts(token) else { return }
                        self.pause(); self.phase = .failed(error.localizedDescription)
                    }
                }
                guard !Task.isCancelled, generation.accepts(token) else { return }
                self.device = device; phase = .live
            } catch {
                guard !Task.isCancelled, generation.accepts(token) else { return }
                switch error {
                case CameraFailure.denied: phase = .denied
                case CameraFailure.unavailable: phase = .unavailable
                default: phase = .failed(error.localizedDescription)
                }
            }
        }
    }
    func capture() async -> UIImage? {
        guard phase == .live else { return nil }
        phase = .capturing
        let token = generation.current
        do {
            let image = try await driver.capture(rotation: captureRotation)
            guard generation.accepts(token), visible, active, !importing else { return nil }
            wantsLive = false; _ = generation.advance(); phase = .frozen; driver.stop()
            return image
        } catch {
            guard generation.accepts(token) else { return nil }
            phase = .failed(error.localizedDescription); return nil
        }
    }
    var message: String? {
        switch phase {
        case .denied: return CameraFailure.denied.localizedDescription
        case .unavailable: return CameraFailure.unavailable.localizedDescription
        case .failed(let message): return message
        default: return nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraController
    func makeCoordinator() -> Coordinator { Coordinator(camera) }
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.preview.videoGravity = .resizeAspect
        view.preview.session = camera.driver.session
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Live rear camera, entire frame"
        view.accessibilityIdentifier = "cameraPreview"
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.configure(device: camera.device, layer: view.preview)
    }
    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        coordinator.previewLayer = nil
        coordinator.observations = []; coordinator.rotation = nil
        coordinator.camera.driver.detachPreview(view.preview)
    }
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    @MainActor final class Coordinator {
        let camera: CameraController
        var rotation: AVCaptureDevice.RotationCoordinator?
        var observations: [NSKeyValueObservation] = []
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        init(_ camera: CameraController) { self.camera = camera }
        func configure(device: AVCaptureDevice?, layer: AVCaptureVideoPreviewLayer) {
            guard let device, rotation == nil else { return }
            let rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
            self.rotation = rotation; previewLayer = layer
            observations = [
                rotation.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, change in
                    guard let angle = change.newValue else { return }
                    Task { @MainActor in
                        if let connection = self?.previewLayer?.connection, connection.isVideoRotationAngleSupported(angle) {
                            connection.videoRotationAngle = angle
                        }
                    }
                },
                rotation.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] _, change in
                    guard let angle = change.newValue else { return }
                    Task { @MainActor in self?.camera.captureRotation = angle }
                }
            ]
        }
    }
}

struct ScannerPreview: View {
    @ObservedObject var scanner: ScannerModel
    @ObservedObject var camera: CameraController
    var body: some View {
        ZStack {
            DexAppearance.lcd
            if let image = scanner.image { Image(uiImage: image).resizable().scaledToFit().padding(8) }
            else if camera.phase == .live || camera.phase == .capturing || camera.phase == .preparing { CameraPreview(camera: camera) }
            else { Image(systemName: "viewfinder").font(.system(size: 70, weight: .ultraLight)) }
        }.clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DexAppearance.bezel, lineWidth: 6))
            .accessibilityElement(children: .contain).accessibilityIdentifier("scanPreview")
    }
}

struct ScannerCaptureControls: View {
    @ObservedObject var camera: CameraController
    let hasImage: Bool
    let working: Bool
    let capture: () -> Void
    let retake: () -> Void
    let importPhoto: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            if hasImage || camera.phase == .frozen {
                Button(action: retake) { label("Retake", "arrow.counterclockwise") }.accessibilityIdentifier("scanRetake")
            } else if camera.phase == .denied {
                Button { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } label: { label("Settings", "gear") }
                    .accessibilityIdentifier("scanCameraSettings")
            } else if case .failed = camera.phase {
                Button(action: retake) { label("Retry camera", "camera") }.accessibilityIdentifier("scanCameraRetry")
            } else {
                Button(action: capture) { label(camera.phase == .preparing ? "Starting…" : "Capture", "camera.fill") }
                    .disabled(camera.phase != .live || working).accessibilityIdentifier("scanCapture")
            }
            Button(action: importPhoto) { label("Import", "photo") }.disabled(working).accessibilityIdentifier("scanImport")
        }.font(.system(size: 14)).buttonStyle(.plain)
            .disabled(camera.phase == .capturing)
    }
    private func label(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).frame(maxWidth: .infinity, minHeight: 44)
            .background(.cyan.gradient, in: RoundedRectangle(cornerRadius: 6))
    }
}
