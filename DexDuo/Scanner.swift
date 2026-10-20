import SwiftUI
import PhotosUI

enum ScannerLayout { case duo, phone }

struct ScannerView: View {
    @ObservedObject var store: DexStore
    @Binding var isPresented: Bool
    var layout = ScannerLayout.duo
    @StateObject private var scanner = ScannerModel()
    @State private var item: PhotosPickerItem?
    @StateObject private var camera = CameraController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var importing = false
    @State private var importTask: Task<Void, Never>?
    @State private var importGeneration = ScanGeneration()
    var body: some View {
        Group {
            if layout == .phone || textSize.isAccessibilitySize {
                PhoneScannerContent(scanner: scanner, camera: camera,
                    capture: capture, retake: retake, importPhoto: openImport, choose: choose,
                    done: { stop(); isPresented = false })
            } else { duoContent }
        }
        .photosPicker(isPresented: $importing, selection: $item, matching: .images)
        .onAppear { camera.open() }
        .onChange(of: importing) { _, shown in
            if !shown { camera.endImport(selected: item != nil) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { background() }
            else if phase == .active { camera.setActive(true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in background() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in camera.setActive(true) }
        .onChange(of: item) { _, value in
            guard let value else { return }
            camera.endImport(selected: true)
            importTask?.cancel(); scanner.cancel()
            let token = importGeneration.advance()
            importTask = Task {
                do {
                    let data = try await value.loadTransferable(type: Data.self)
                    guard !Task.isCancelled, isPresented, importGeneration.accepts(token) else { return }
                    guard let data, let photo = UIImage(data: data) else { throw RecognitionError.invalidImage }
                    analyze(photo)
                } catch {
                    if !Task.isCancelled && importGeneration.accepts(token) { scanner.showMessage("Couldn’t open this image. Please try another.") }
                }
            }
        }
        .onDisappear { stop() }
        .onChange(of: isPresented) { _, active in if !active { stop() } }
    }
    private var duoContent: some View {
        NavigationStack {
            GeometryReader { space in
                let scale = min(space.size.width / 380, space.size.height / 680)
                VStack(spacing: 10) {
                    ScannerPreview(scanner: scanner, camera: camera).frame(height: 130)
                    Text("CARD & SCREEN SCANNER").font(.caption.monospaced().bold())
                    Text((scanner.image == nil && camera.phase != .frozen) ? (camera.message ?? "Point at one Pokémon, then press Capture.") : scanner.message).multilineTextAlignment(.center).font(.system(size: 14)).lineLimit(3).frame(height: 50)
                        .accessibilityIdentifier("scanMessage")
                    if scanner.working { ProgressView("Identifying Pokémon…") }
                    ScannerCaptureControls(camera: camera, hasImage: scanner.image != nil, working: scanner.working,
                        capture: capture, retake: retake, importPhoto: openImport)
                    ForEach(scanner.candidates.prefix(3)) { candidate in
                        Button { choose(candidate) } label: {
                            HStack { Text(scanner.retryCandidate == candidate ? "Retry " + candidate.name : candidate.name); Spacer(); Image(systemName: "chevron.right") }.padding(8)
                        }.buttonStyle(.bordered).disabled(scanner.working)
                            .accessibilityIdentifier("scanCandidate-\(candidate.speciesID)")
                    }
                    Text("Recognizes 1,025 Pokémon species from appearance. Images are processed on your device. Uncertain matches need confirmation.")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(4)
                }.padding(24)
                    .frame(width: 380, height: 680, alignment: .top)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: space.size.width, height: space.size.height, alignment: .top)
            }.navigationTitle("Scan Pokémon")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { stop(); isPresented = false } } }
        }
    }
    private func stop() { camera.close(); importTask?.cancel(); _ = importGeneration.advance(); scanner.cancel() }
    private func background() {
        camera.setActive(false)
        importTask?.cancel(); _ = importGeneration.advance()
        if scanner.working || (item != nil && scanner.image == nil) {
            scanner.cancel(); scanner.showMessage("Scan paused. Retake or import an image to try again.")
        }
    }
    private func analyze(_ image: UIImage) { guard isPresented else { return }; scanner.analyze(image, select: { await store.select($0) }, dismiss: { isPresented = false }) }
    private func choose(_ candidate: PokemonLabel) { guard isPresented else { return }; scanner.choose(candidate, select: { await store.select($0) }, dismiss: { isPresented = false }) }
    private func capture() {
        Task { if let image = await camera.capture() { analyze(image) } }
    }
    private func retake() {
        importTask?.cancel(); _ = importGeneration.advance(); scanner.reset(); camera.retake()
    }
    private func openImport() {
        item = nil; camera.beginImport(); importing = true
    }
}
