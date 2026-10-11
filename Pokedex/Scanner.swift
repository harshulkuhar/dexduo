import SwiftUI
import PhotosUI
import Vision
import AVFoundation

struct ScannerView: View {
    @ObservedObject var store: DexStore
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var camera = false
    @State private var working = false
    @State private var message = "Capture a card or import a screen image with a readable Pokémon name."
    @State private var candidates: [Named] = []
    var body: some View {
        NavigationStack {
            GeometryReader { space in
                let scale = min(space.size.width / 380, space.size.height / 680)
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.08))
                        if let image { Image(uiImage: image).resizable().scaledToFit().padding(12) }
                        else { Image(systemName: "viewfinder").font(.system(size: 100, weight: .ultraLight)).foregroundStyle(.secondary) }
                    }.frame(height: 180)
                    Text("CARD & SCREEN SCANNER").font(.caption.monospaced().bold())
                    Text(message).multilineTextAlignment(.center)
                    if working { ProgressView("Reading image…") }
                    HStack {
                        Button { Task { await openCamera() } } label: { Label("Camera", systemImage: "camera.fill") }
                        PhotosPicker(selection: $item, matching: .images) { Label("Import", systemImage: "photo") }
                    }.buttonStyle(.borderedProminent).disabled(working)
                    ForEach(candidates.prefix(3)) { candidate in
                        Button { Task { await store.select(candidate.name); dismiss() } } label: {
                            HStack { Text(candidate.title); Spacer(); Image(systemName: "chevron.right") }.padding()
                        }.buttonStyle(.bordered)
                    }
                    Text("This first version reads names using on-device text recognition. Artwork-only Pokémon classification is not integrated yet. Images stay on your device.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
                    .frame(width: 380, height: 680, alignment: .top)
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: space.size.width, height: space.size.height, alignment: .top)
            }.navigationTitle("Scan Pokémon")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(isPresented: $camera) { CameraPicker { photo in image = photo; Task { await recognize(photo) } } }
        .onChange(of: item) { _, value in
            Task {
                do {
                    guard let data = try await value?.loadTransferable(type: Data.self), let photo = UIImage(data: data) else { return }
                    image = photo; await recognize(photo)
                } catch { message = "Couldn’t open this image. Please try another." }
            }
        }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message = "The Simulator has no camera. Use Import to test a card photo or screenshot."; return }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed { camera = true } else { message = "Camera access is off. Enable it for Pokédex in Settings, or import a photo." }
    }
    private func recognize(_ photo: UIImage) async {
        working = true; candidates = []; defer { working = false }
        // Render upright before sending the image to Vision.
        let size = CGSize(width: min(photo.size.width, 1800), height: min(photo.size.width, 1800) * photo.size.height / photo.size.width)
        let upright = UIGraphicsImageRenderer(size: size).image { _ in photo.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = upright.jpegData(compressionQuality: 0.9) else { return }
        do {
            let lines = try await Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]
                request.usesLanguageCorrection = false
                try VNImageRequestHandler(data: data).perform([request])
                return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            }.value
            candidates = Array(store.names.filter { pokemon in
                let name = normalized(pokemon.name)
                return lines.contains { line in
                    let cleaned = normalized(line)
                    return cleaned == name || ["ex", "gx", "v", "vmax", "vstar"].contains { cleaned == name + $0 }
                }
            }.prefix(8))
            message = candidates.isEmpty ? "No readable Pokémon name matched. Try a close, glare-free photo with the card title visible, or use search." : "Names found in the image. Choose the Pokémon you want to view."
        } catch { message = "Couldn’t read this image. Try another capture." }
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
