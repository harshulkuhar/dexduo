import XCTest
import UIKit
import SwiftUI
@testable import DexDuo

final class PhoneLayoutTests: XCTestCase {
    func testPhoneTabletAndLatchedDuoProfiles() {
        var state = DeviceProfileState()
        XCTAssertEqual(state.profile, .unresolved)
        state.observe(isPhone: true, hasHinge: false, closed: nil)
        XCTAssertEqual(state.profile, .phone)
        state.observe(isPhone: true, hasHinge: true, closed: nil)
        XCTAssertEqual(state.profile, .duo)
        XCTAssertTrue(state.isFolded)
        state.observe(isPhone: true, hasHinge: true, closed: false)
        XCTAssertFalse(state.isFolded)
        state.observe(isPhone: true, hasHinge: false, closed: nil)
        XCTAssertEqual(state.profile, .duo)
        XCTAssertFalse(state.isFolded)
        state.observe(isPhone: true, hasHinge: true, closed: true)
        XCTAssertTrue(state.isFolded)
        var tablet = DeviceProfileState()
        tablet.observe(isPhone: false, hasHinge: false, closed: nil)
        XCTAssertEqual(tablet.profile, .tablet)
    }

    func testRepeatedFoldUpdatesNeverChangeDuoOrientationPolicy() {
        XCTAssertEqual(DeviceProfile.phone.orientationMask, [.landscapeLeft, .landscapeRight])
        XCTAssertFalse(DeviceProfile.phone.orientationMask.contains(.portrait))
        var state = DeviceProfileState()
        for _ in 0..<20 {
            for closed in [false, true] {
                state.observe(isPhone: true, hasHinge: true, closed: closed)
                state.observe(isPhone: true, hasHinge: false, closed: nil)
                XCTAssertEqual(state.profile, .duo)
                XCTAssertEqual(state.isFolded, closed)
                XCTAssertEqual(state.profile.orientationMask, .portrait)
            }
        }
    }

    func testAllTypesFitCompactAndNotchedPhonePanels() {
        for size in [CGSize(width: 667, height: 375), CGSize(width: 724, height: 354), CGSize(width: 832, height: 419)] {
            let metrics = PhoneLayoutMetrics(size: size)
            let bodyHeight = size.height - 16 - PhoneLayoutMetrics.toolbarHeight - PhoneLayoutMetrics.spacing
            let grid = CGSize(width: metrics.panelWidth - 16, height: bodyHeight - 44 - 8 - 16 - 21)
            XCTAssertNotNil(TypeGridArrangement.fitting(in: grid), "\(size)")
            let center = PhoneLayoutMetrics.margin + metrics.panelWidth + PhoneLayoutMetrics.spacing + PhoneLayoutMetrics.dividerWidth / 2
            XCTAssertEqual(center, size.width / 2, accuracy: 0.001)
        }
    }

    func testKeyboardIntersectionUsesVisibleBoundsWithoutDoubleSubtractingSafeArea() {
        let bounds = CGRect(x: 0, y: 0, width: 667, height: 354)
        XCTAssertEqual(PhoneLayoutMetrics.visibleHeight(bounds: bounds, keyboard: CGRect(x: 0, y: 177, width: 667, height: 198)), 177)
        XCTAssertEqual(PhoneLayoutMetrics.visibleHeight(bounds: bounds, keyboard: CGRect(x: 0, y: 375, width: 667, height: 198)), 354)
        XCTAssertEqual(PhoneLayoutMetrics.visibleHeight(bounds: bounds, keyboard: nil), 354)
        XCTAssertEqual(PhoneLayoutMetrics.resultCapacity(height: 44), 1)
        XCTAssertEqual(PhoneLayoutMetrics.resultCapacity(height: 92), 2)
        XCTAssertEqual(PhoneLayoutMetrics.resultCapacity(height: 500), 3)
        XCTAssertEqual(PhoneLayoutMetrics.resultCapacity(height: 307, maximum: 8), 6)
    }


}

// Render the actual phone components at their intended point sizes, independently
// of which device profiles the installed Simulator runtime supports.
@MainActor final class PhoneRenderingTests: XCTestCase {
    func testPhoneCoverAndInteriorAtCompactNotchedAndLargeSizes() async throws {
        let store = try makeStore()
        for size in [CGSize(width: 667, height: 375), CGSize(width: 812, height: 375), CGSize(width: 956, height: 440)] {
            let insets = size.width == 667 ? EdgeInsets() : EdgeInsets(top: 0, leading: 44, bottom: 21, trailing: 44)
            try render(PhoneCover(safeAreaInsets: insets, open: {}), size: size, name: "cover-\(Int(size.width))")
            try render(PhoneDexView(store: store, presentation: DevicePresentation(), opened: .constant(true), scanning: .constant(false))
                .padding(insets), size: size, name: "interior-\(Int(size.width))")
            let metrics = PhoneLayoutMetrics(size: CGSize(width: size.width - insets.leading - insets.trailing,
                                                          height: size.height - insets.bottom))
            let bodyHeight = size.height - insets.bottom - 16 - PhoneLayoutMetrics.toolbarHeight - PhoneLayoutMetrics.spacing
            try render(DexDetails(store: store, tab: .constant(.types)),
                       size: CGSize(width: metrics.panelWidth, height: bodyHeight), name: "types-\(Int(size.width))", checkTypes: true)
            try render(DexDetails(store: store, tab: .constant(.stats)),
                       size: CGSize(width: metrics.panelWidth, height: bodyHeight), name: "stats-\(Int(size.width))")
        }
    }

    func testAccessibilityDetailsRetainAllTypes() throws {
        let store = try makeStore()
        try render(PhoneDexView(store: store, presentation: DevicePresentation(), opened: .constant(true), scanning: .constant(false)).environment(\.dynamicTypeSize, .accessibility5),
                   size: CGSize(width: 667, height: 375), name: "interior-accessibility")
        try render(DexDetails(store: store, tab: .constant(.types)).environment(\.dynamicTypeSize, .accessibility5),
                   size: CGSize(width: 643, height: 255), name: "types-accessibility", checkTypes: true)
        try render(DexDetails(store: store, tab: .constant(.stats)).environment(\.dynamicTypeSize, .accessibility5),
                   size: CGSize(width: 643, height: 255), name: "stats-accessibility")
        try render(DexDetails(store: store, tab: .constant(.info)).environment(\.dynamicTypeSize, .accessibility5),
                   size: CGSize(width: 643, height: 255), name: "info-accessibility")
    }

    func testSearchFieldKeepsItsInstanceWhileTypingAndClearing() async throws {
        let store = try makeStore()
        store.names = [Named(name: "espeon", url: ""), Named(name: "pikachu", url: "")]
        let controller = UIHostingController(rootView: PhoneDexView(store: store, presentation: DevicePresentation(), opened: .constant(true), scanning: .constant(false)).environmentObject(EntrySpeech()))
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 667, height: 375))
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let field = try XCTUnwrap(textField(in: controller.view))
        XCTAssertTrue(field.becomeFirstResponder())
        for character in "espeon" {
            field.insertText(String(character))
            try await Task.sleep(for: .milliseconds(20))
            XCTAssertTrue(textField(in: controller.view) === field)
        }
        XCTAssertEqual(store.query, "espeon")
        XCTAssertEqual(store.matches.first?.name, "espeon")
        store.query = ""
        try await Task.sleep(for: .milliseconds(20))
        field.insertText("pikachu")
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(store.query, "pikachu")
        XCTAssertTrue(textField(in: controller.view) === field)
        field.resignFirstResponder()
    }

    func testScannerCandidatesAndFailedLookupRenderAtCompactAndAccessibilitySizes() async throws {
        let labels = [PokemonLabel(index: 195, speciesID: 196, name: "Espeon", apiName: "espeon"),
                      PokemonLabel(index: 739, speciesID: 740, name: "Crabominable", apiName: "crabominable"),
                      PokemonLabel(index: 24, speciesID: 25, name: "Pikachu", apiName: "pikachu")]
        let scanner = ScannerModel { _ in
            RecognitionResult(visual: zip(labels, [0.6, 0.3, 0.1]).map { VisualPrediction(label: $0.0, probability: $0.1) }, policy: .provisional)
        }
        scanner.analyze(UIImage(), select: { _ in XCTFail("Confirmation is required"); return false }, dismiss: {})
        for _ in 0..<100 where scanner.working { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(scanner.candidates, labels)
        try render(PhoneScannerContent(scanner: scanner, item: .constant(nil), openCamera: {}, choose: { _ in }, done: {}),
                   size: CGSize(width: 667, height: 375), name: "scanner-compact")
        scanner.choose(labels[0], select: { _ in false }, dismiss: { XCTFail("A failed lookup must stay open") })
        for _ in 0..<100 where scanner.working { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(scanner.retryCandidate, labels[0])
        try render(PhoneScannerContent(scanner: scanner, item: .constant(nil), openCamera: {}, choose: { _ in }, done: {})
            .environment(\.dynamicTypeSize, .accessibility5), size: CGSize(width: 667, height: 375), name: "scanner-retry-accessibility")
    }

    func testEvolutionChartsRenderAtCompactNotchedAndAccessibilitySizes() async throws {
        let repository = EvolutionRepository(api: try EvolutionFixtureAPI())
        let model = EvolutionModel(repository: repository)
        let store = DexStore()
        for species in ["geodude", "gastly", "eevee", "wurmple", "applin", "ditto"] {
            store.pokemon = try await repository.member(for: species)
            await model.load(for: species)
            for size in [CGSize(width: 312, height: 307), CGSize(width: 341, height: 286)] {
                try render(DexDetails(store: store, tab: .constant(.evolution)).environmentObject(model),
                           size: size, name: "evolution-\(species)-\(Int(size.width))")
            }
        }
        store.pokemon = try await repository.member(for: "eevee")
        await model.load(for: "eevee")
        try render(DexDetails(store: store, tab: .constant(.evolution)).environmentObject(model)
            .environment(\.dynamicTypeSize, .accessibility5), size: CGSize(width: 643, height: 255), name: "evolution-accessibility")
    }

    private func textField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField { return field }
        return view.subviews.lazy.compactMap { self.textField(in: $0) }.first
    }

    private func makeStore() throws -> DexStore {
        let data = Data("""
        {"id":130,"name":"gyarados","height":65,"weight":2350,
         "types":[{"type":{"name":"water","url":""}},{"type":{"name":"flying","url":""}}],
         "abilities":[{"ability":{"name":"intimidate","url":""}},{"ability":{"name":"moxie","url":""}}],
         "stats":[{"base_stat":95,"stat":{"name":"hp","url":""}},{"base_stat":125,"stat":{"name":"attack","url":""}},{"base_stat":79,"stat":{"name":"defense","url":""}},{"base_stat":60,"stat":{"name":"special-attack","url":""}},{"base_stat":100,"stat":{"name":"special-defense","url":""}},{"base_stat":81,"stat":{"name":"speed","url":""}}],
         "species":{"name":"gyarados","url":""},"sprites":{"front_default":null}}
        """.utf8)
        let store = DexStore()
        store.pokemon = try JSONDecoder().decode(Pokemon.self, from: data)
        store.entryText = String(repeating: "Once Gyarados appears, its rage never settles until it has razed the fields and mountains around it. ", count: 20)
        store.entryVersion = "Scarlet"
        return store
    }

    private func render<Content: View>(_ content: Content, size: CGSize, name: String, checkTypes: Bool = false) throws {
        let controller = UIHostingController(rootView: content.environmentObject(EntrySpeech()).foregroundStyle(DexAppearance.ink).background(DexAppearance.shell)
            .environment(\.colorScheme, .light).frame(width: size.width, height: size.height))
        controller.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(controller.view.bounds.size, size)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if checkTypes {
            let cg = try XCTUnwrap(image.cgImage)
            var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8,
                bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(origin: .zero, size: size))
            for type in PokemonType.allCases {
                let rgb = type.rgb
                var matching = 0
                for offset in stride(from: 0, to: pixels.count, by: 4) {
                    if abs(Int(pixels[offset]) - Int((rgb >> 16) & 255)) <= 2 &&
                        abs(Int(pixels[offset + 1]) - Int((rgb >> 8) & 255)) <= 2 &&
                        abs(Int(pixels[offset + 2]) - Int(rgb & 255)) <= 2 { matching += 1 }
                }
                XCTAssertGreaterThan(matching, 100, "Missing \(type) header at \(size)")
            }
        }
    }
}
