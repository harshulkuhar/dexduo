import SwiftUI
import PhotosUI
import AVFoundation

struct ScannerView: View {
    @ObservedObject var store: DexStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = ScannerModel()
    @State private var item: PhotosPickerItem?
    @State private var camera = false
    @State private var isVisible = false
    @State private var importTask: Task<Void, Never>?
    @State private var importGeneration = ScanGeneration()
    var body: some View {
        NavigationStack {
            GeometryReader { space in
                let scale = min(space.size.width / 380, space.size.height / 680)
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.08))
                        if let image = scanner.image { Image(uiImage: image).resizable().scaledToFit().padding(12) }
                        else { Image(systemName: "viewfinder").font(.system(size: 100, weight: .ultraLight)).foregroundStyle(.secondary) }
                    }.frame(height: 130)
                    Text("CARD & SCREEN SCANNER").font(.caption.monospaced().bold())
                    Text(scanner.message).multilineTextAlignment(.center).font(.system(size: 14)).lineLimit(3).frame(height: 50)
                        .accessibilityIdentifier("scanMessage")
                    if scanner.working { ProgressView("Identifying Pokémon…") }
                    HStack {
                        Button { Task { await openCamera() } } label: { Label("Camera", systemImage: "camera.fill") }
                        PhotosPicker(selection: $item, matching: .images) { Label("Import", systemImage: "photo") }
                            .accessibilityIdentifier("scanImport")
                    }.buttonStyle(.borderedProminent).disabled(scanner.working)
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
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { stop(); dismiss() } } }
        }
        .sheet(isPresented: $camera) { CameraPicker { photo in analyze(photo) } }
        .onChange(of: item) { _, value in
            importTask?.cancel(); scanner.cancel()
            let token = importGeneration.advance()
            importTask = Task {
                do {
                    guard let data = try await value?.loadTransferable(type: Data.self), !Task.isCancelled,
                          importGeneration.accepts(token), let photo = UIImage(data: data) else { return }
                    analyze(photo)
                } catch {
                    if !Task.isCancelled && importGeneration.accepts(token) { scanner.showMessage("Couldn’t open this image. Please try another.") }
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; stop() }
    }
    private func stop() { isVisible = false; importTask?.cancel(); _ = importGeneration.advance(); scanner.cancel() }
    private func analyze(_ image: UIImage) { guard isVisible else { return }; scanner.analyze(image, select: { await store.select($0) }, dismiss: { dismiss() }) }
    private func choose(_ candidate: PokemonLabel) { scanner.choose(candidate, select: { await store.select($0) }, dismiss: { dismiss() }) }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            scanner.showMessage("The Simulator has no camera. Use Import to test a card photo or screenshot."); return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed { camera = true }
        else { scanner.showMessage("Camera access is off. Enable it for Pokédex in Settings, or import a photo.") }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.cameraDevice = .rear; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.dismiss()
            if let image = info[.originalImage] as? UIImage { parent.completion(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
