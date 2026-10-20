import SwiftUI
import UIKit

struct PhoneScannerContent: View {
    @ObservedObject var scanner: ScannerModel
    @ObservedObject var camera: CameraController
    let capture: () -> Void
    let retake: () -> Void
    let importPhoto: () -> Void
    let choose: (PokemonLabel) -> Void
    let done: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var candidateFont: CGFloat = 14
    @State private var panel = "Results"
    @State private var page = 0

    var body: some View {
        GeometryReader { space in
            VStack(spacing: 8) {
                HStack {
                    Text("Scan Pokémon").font(.system(size: 18, weight: .bold, design: .monospaced))
                    Spacer()
                    Button("Done", action: done).font(.system(size: 14, weight: .semibold)).frame(minWidth: 44, minHeight: 44)
                }.frame(height: 44)
                if textSize.isAccessibilitySize {
                    Picker("Scanner panel", selection: $panel) {
                        Text("Preview").tag("Preview")
                        Text("Results").tag("Results")
                    }.pickerStyle(.segmented).frame(height: 44)
                    if panel == "Preview" { ScannerPreview(scanner: scanner, camera: camera) } else { results }
                    controls
                } else {
                    HStack(spacing: 12) {
                        ScannerPreview(scanner: scanner, camera: camera).frame(maxWidth: .infinity)
                        results.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(width: space.size.width, height: space.size.height, alignment: .top)
        }
        .foregroundStyle(DexAppearance.ink)
        .background(DexAppearance.shell.gradient)
        .accessibilityElement(children: .contain).accessibilityIdentifier("phoneScanner")
        .onChange(of: scanner.image) { _, _ in page = 0 }
    }

    private var controls: some View {
        ScannerCaptureControls(camera: camera, hasImage: scanner.image != nil, working: scanner.working,
            capture: capture, retake: retake, importPhoto: importPhoto)
    }

    private var results: some View {
        VStack(spacing: 8) {
            Text((scanner.image == nil && camera.phase != .frozen) ? (camera.message ?? "Point at one Pokémon, then press Capture.") : scanner.message).font(.system(size: 14)).lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 51, alignment: .topLeading)
                .accessibilityIdentifier("scanMessage")
            if !textSize.isAccessibilitySize { controls }
            if scanner.working {
                ProgressView("Identifying Pokémon…").frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else if !scanner.candidates.isEmpty {
                GeometryReader { space in
                    let rowHeight = max(44, UIFont.systemFont(ofSize: candidateFont).lineHeight * 2 + 8)
                    let capacity = PhoneLayoutMetrics.resultCapacity(height: space.size.height, rowHeight: rowHeight)
                    let count = (scanner.candidates.count + capacity - 1) / capacity
                    let current = min(page, count - 1)
                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 4) {
                            ForEach(Array(scanner.candidates.dropFirst(current * capacity).prefix(capacity))) { candidate in
                                Button { choose(candidate) } label: {
                                    HStack {
                                        Text((scanner.retryCandidate == candidate ? "Retry " : "") + candidate.name)
                                            .font(.system(size: candidateFont)).lineLimit(2)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                    }.padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: rowHeight)
                                }.background(DexAppearance.lcd, in: RoundedRectangle(cornerRadius: 6))
                                    .accessibilityIdentifier("scanCandidate-\(candidate.speciesID)")
                            }
                        }.frame(maxWidth: .infinity)
                        if count > 1 {
                            PhonePageControls(page: $page, count: count, identifier: "scan").frame(width: 132)
                        }
                    }
                }
            } else {
                Text("Images are processed on your device.").font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }.padding(8).background(DexAppearance.bezel, in: RoundedRectangle(cornerRadius: 10))
    }
}
