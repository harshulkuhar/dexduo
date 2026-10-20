import SwiftUI

@MainActor final class OrientationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        DevicePresentation.orientations(for: window)
    }
}

@main struct DexDuoApp: App {
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var delegate
    var body: some Scene { WindowGroup { DexDuoView() } }
}

private let shell = DexAppearance.shell
private let ink = DexAppearance.ink
private let lcd = DexAppearance.lcd

struct DexDuoView: View {
    @StateObject private var store = DexStore()
    @StateObject private var presentation = DevicePresentation()
    @Environment(\.scenePhase) private var scenePhase
    @State private var opened = false
    @State private var hardwareControlsCover = true
    @State private var scanning = false
    @State private var tab = "Info"
    @State private var compactPanel = "Pokémon"
    @FocusState private var searchFocused: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.87, green: 0.14, blue: 0.20), shell, Color(red: 0.49, green: 0.03, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch presentation.state.profile {
            case .phone:
                PhoneDexView(store: store, presentation: presentation, opened: $opened)
            case .duo, .tablet:
                ZStack {
                    if opened { FixedInterior { interior }.accessibilityElement(children: .contain).accessibilityIdentifier("duoInterior") }
                    if !opened { cover.ignoresSafeArea(.container, edges: .all) }
                }.ignoresSafeArea(.container, edges: .horizontal)
                    .accessibilityElement(children: .contain).accessibilityIdentifier(presentation.state.profile == .duo ? "duoPresentation" : "tabletPresentation")
            case .unresolved:
                Color.clear
            }
        }
        .background(DeviceProfileProbe(presentation: presentation).frame(width: 0, height: 0).accessibilityHidden(true))
        .onChange(of: presentation.state.profile) { _, _ in applyDeviceState() }
        .onChange(of: presentation.state.isFolded) { _, _ in applyDeviceState() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentation.requestLandscapeIfNeeded() }
        }
        // Keyboard presentation must not change the instrument coordinate system
        // or replace the focused field through the wide/compact layout branch.
        .ignoresSafeArea(.keyboard)
        .statusBarHidden(true)
        .preferredColorScheme(.light)
        .sheet(isPresented: $scanning) { ScannerView(store: store, isPresented: $scanning) }
        .task { await store.start() }
    }
    private func applyDeviceState() {
        hardwareControlsCover = presentation.state.profile == .duo
        guard hardwareControlsCover else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if presentation.state.isFolded { scanning = false; searchFocused = false }
            opened = !presentation.state.isFolded
        }
    }
    private var interior: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(.black.opacity(0.25)).frame(height: 2).padding(.bottom, 20)
            GeometryReader { space in
                let wide = space.size.width > 650
                let canvas = CGSize(width: wide ? max(720, space.size.width * 570 / max(space.size.height, 1)) : 380,
                                    height: wide ? 570 : 610)
                let scale = min(space.size.width / canvas.width, space.size.height / canvas.height)
                VStack(spacing: 16) {
                    if wide {
                        HStack(alignment: .top, spacing: 24) {
                            display.frame(maxWidth: .infinity)
                            RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.18)).frame(width: 10, height: 510)
                            controls.frame(maxWidth: .infinity)
                        }
                    } else {
                        Picker("Panel", selection: $compactPanel) {
                            Text("Pokémon").tag("Pokémon")
                            Text("Search & details").tag("Details")
                        }.pickerStyle(.segmented)
                        if compactPanel == "Pokémon" { display } else { controls }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .frame(width: canvas.width, height: canvas.height)
                .scaleEffect(scale, anchor: .top)
                .frame(width: space.size.width, height: space.size.height, alignment: .top)
            }
        }.frame(maxWidth: .infinity)
    }
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { scanning = true } label: {
                Circle().fill(.cyan.gradient).frame(width: 56, height: 56)
                    .overlay(alignment: .topLeading) { Circle().fill(.white.opacity(0.7)).frame(width: 15).offset(x: 12, y: 9) }
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 5)).compositingGroup().shadow(color: .black.opacity(0.4), radius: 2, y: 4)
            }.accessibilityLabel("Open Pokémon scanner")
            HStack(spacing: 7) { ForEach([Color.red, .yellow, .green], id: \.self) { color in Circle().fill(color.gradient).frame(width: 11, height: 11).overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 1)) } }.padding(.leading, 5)
            Spacer()
            if !hardwareControlsCover {
            Button { withAnimation(.easeInOut(duration: 0.25)) { opened.toggle() } } label: {
                Label(opened ? "Cover" : "Open", systemImage: opened ? "book.closed" : "book")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced)).padding(12)
                    .background(.black.opacity(0.16), in: Capsule())
            }.tint(.white)
            }
        }.padding(.horizontal, 28).padding(.vertical, 20)
    }
    private var cover: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                // Continuous red shell; the stepped lid seam follows the Kanto design.
                LinearGradient(colors: [Color(red: 0.91, green: 0.12, blue: 0.17), shell], startPoint: .topLeading, endPoint: .bottomTrailing)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.23))
                    path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.23))
                    path.addLine(to: CGPoint(x: w * 0.57, y: h * 0.16))
                    path.addLine(to: CGPoint(x: w, y: h * 0.16))
                }.stroke(Color(red: 0.42, green: 0.03, blue: 0.06), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                Path { path in
                    path.move(to: CGPoint(x: w * 0.07, y: h * 0.28))
                    path.addLine(to: CGPoint(x: w * 0.43, y: h * 0.28))
                    path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.21))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.21))
                    path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.94))
                    path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.97), control: CGPoint(x: w * 0.88, y: h * 0.97))
                    path.addLine(to: CGPoint(x: w * 0.07, y: h * 0.97))
                    path.closeSubpath()
                }.fill(shell.opacity(0.24))
                Circle().fill(Color.white.opacity(0.92)).frame(width: w * 0.245)
                    .overlay {
                        Circle().fill(RadialGradient(colors: [.white, Color(red: 0.22, green: 0.85, blue: 0.98), Color(red: 0.02, green: 0.43, blue: 0.74)], center: .topLeading, startRadius: 0, endRadius: w * 0.22))
                            .padding(7).overlay(Circle().stroke(.black.opacity(0.22), lineWidth: 2).padding(7))
                    }.compositingGroup().shadow(color: .black.opacity(0.35), radius: 2, y: 3)
                    .position(x: w * 0.19, y: h * 0.11)
                HStack(spacing: w * 0.025) {
                    ForEach([Color.red, .yellow, .green], id: \.self) { color in
                        Circle().fill(color.gradient).frame(width: w * 0.034, height: w * 0.034)
                            .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: 1.5))
                    }
                }.position(x: w * 0.45, y: h * 0.065)
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: w * 0.11)).foregroundStyle(Color(red: 1, green: 0.79, blue: 0.08))
                    .shadow(color: .black.opacity(0.45), radius: 1, y: 3)
                    .position(x: w * 0.095, y: h * 0.53)
            }
            .contentShape(Rectangle())
            .onTapGesture { if !hardwareControlsCover { opened = true } }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("duoCover")
            .accessibilityLabel("Closed DexDuo cover")
            .accessibilityHint(hardwareControlsCover ? "Unfold the device to open the DexDuo" : "Double tap to open")
        }
    }
    private var display: some View {
        VStack(spacing: 22) {
            VStack(spacing: 14) {
                HStack(spacing: 10) { Circle().fill(shell).frame(width: 7); Circle().fill(shell).frame(width: 7) }.frame(height: 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(lcd.gradient)
                    VStack(spacing: 10) {
                        HStack {
                            Text(store.pokemon.map { String(format: "No. %04d", $0.id) } ?? "CONNECTING")
                            Spacer(); Image(systemName: "waveform.path")
                        }.font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(ink.opacity(0.7))
                        if let pokemon = store.pokemon {
                            Group {
                                if let image = store.artworkImage {
                                    Image(uiImage: image).resizable().scaledToFit()
                                } else if store.artworkFailed {
                                    Image(systemName: "photo").font(.system(size: 55)).foregroundStyle(ink.opacity(0.4))
                                } else { ProgressView() }
                            }.frame(height: 220).compositingGroup().shadow(color: ink.opacity(0.15), radius: 9, y: 12)
                            Text(pokemon.title.uppercased()).font(.system(size: 26, weight: .black, design: .rounded)).tracking(2).minimumScaleFactor(0.5).lineLimit(1)
                            HStack { ForEach(pokemon.types, id: \.type.name) { kind in PokemonTypeBadge(name: kind.type.name) } }
                        } else { ProgressView("Loading DexDuo…").frame(height: 290) }
                    }.foregroundStyle(ink).padding(20)
                    if store.loading && store.pokemon != nil { ProgressView().padding().background(.regularMaterial, in: Capsule()) }
                }.overlay(RoundedRectangle(cornerRadius: 10).stroke(ink.opacity(0.6), lineWidth: 3))
                HStack { Circle().fill(shell.gradient).frame(width: 23); Spacer(); VStack(spacing: 4) { ForEach(0..<3) { _ in Capsule().fill(ink.opacity(0.65)).frame(width: 45, height: 3) } } }.padding(.horizontal, 6)
            }.padding(18).background(Color(red: 0.91, green: 0.91, blue: 0.85), in: RoundedRectangle(cornerRadius: 19)).compositingGroup().shadow(color: .black.opacity(0.3), radius: 0, y: 6)
            HStack {
                HStack(spacing: 0) {
                    Button { Task { await store.step(-1) } } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }.accessibilityLabel("Previous Pokémon")
                    Button { Task { await store.step(1) } } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }.accessibilityLabel("Next Pokémon")
                }.font(.headline).foregroundStyle(.white).background(ink.gradient, in: RoundedRectangle(cornerRadius: 10)).disabled(store.loading)
                Spacer()
                Text("●  \(store.loading ? "LOADING" : "DEX ONLINE")").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(ink).padding(14).background(lcd, in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("POKÉMON DATABASE").font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(.white.opacity(0.7))
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search Pokémon…", text: $store.query)
                    .focused($searchFocused)
                    .accessibilityIdentifier("pokemonSearch")
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        if let match = store.matches.first {
                            searchFocused = false
                            store.query = ""
                            Task { await store.select(match.name) }
                        }
                    }
                Button { store.query = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search").opacity(store.query.isEmpty ? 0 : 1).disabled(store.query.isEmpty)
            }.padding(16).foregroundStyle(ink).background(Color.white.opacity(0.93), in: RoundedRectangle(cornerRadius: 10))
            if !store.query.isEmpty {
                VStack(spacing: 0) {
                    if store.matches.isEmpty { Text("No matching names").padding() }
                    ForEach(store.matches.prefix(4)) { match in
                        Button { searchFocused = false; store.query = ""; Task { await store.select(match.name) } } label: {
                            HStack { Text(match.title); Spacer(); Image(systemName: "arrow.up.left") }.padding(12)
                        }.foregroundStyle(ink).accessibilityIdentifier("searchCandidate-\(match.name)")
                    }
                }.background(lcd, in: RoundedRectangle(cornerRadius: 10))
            }
            if let error = store.error {
                VStack(alignment: .leading) { Text(error); Button("Retry") { Task { await store.start() } } }.font(.footnote).padding().background(.white, in: RoundedRectangle(cornerRadius: 8))
            }
            if store.query.isEmpty {
            HStack(spacing: 8) {
                ForEach(["Info", "Stats", "Types"], id: \.self) { label in
                    Button { tab = label } label: { Text(label.uppercased()).font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(2).frame(maxWidth: .infinity).padding(.vertical, 14).background(tab == label ? Color.cyan : Color(red: 0.16, green: 0.39, blue: 0.52), in: RoundedRectangle(cornerRadius: 5)).foregroundStyle(tab == label ? ink : .white) }.accessibilityIdentifier("detailTab-\(label.lowercased())")
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if let pokemon = store.pokemon {
                    Text(pokemon.title).font(.system(size: 23, weight: .bold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.65)
                    Rectangle().fill(ink.opacity(0.2)).frame(height: 1)
                    if tab == "Info" {
                        Text(store.entryText)
                            .font(.system(size: 15)).lineLimit(7).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        if !store.entryVersion.isEmpty {
                            Text("DEXDUO · " + store.entryVersion.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(ink.opacity(0.6))
                        }
                        infoRow("HEIGHT", String(format: "%.1f m", Double(pokemon.height) / 10))
                        infoRow("WEIGHT", String(format: "%.1f kg", Double(pokemon.weight) / 10))
                    } else if tab == "Types" {
                        TypeMatchupsView(defendingTypes: pokemon.types.map { $0.type.name })
                    } else {
                        VStack(spacing: 6) {
                            ForEach(pokemon.stats, id: \.stat.name) { stat in
                                HStack {
                                    Text(stat.stat.title).font(.system(size: 11, design: .monospaced)).frame(width: 105, alignment: .leading)
                                    ProgressView(value: Double(stat.base_stat), total: 255).tint(ink)
                                    Text("\(stat.base_stat)").font(.caption.monospaced()).frame(width: 28)
                                }
                            }
                        }
                        infoRow("BASE STAT TOTAL", "\(pokemon.baseStatTotal)")
                        Rectangle().fill(ink.opacity(0.2)).frame(height: 1)
                        Text("ABILITIES").font(.system(size: 10, design: .monospaced)).foregroundStyle(ink.opacity(0.6))
                        Text(pokemon.abilities.map { $0.ability.title }.joined(separator: " · "))
                            .font(.system(size: 13, design: .monospaced)).lineLimit(2).minimumScaleFactor(0.8)
                    }
                }
            }.foregroundStyle(ink).padding(tab == "Types" ? 12 : 20).frame(maxWidth: .infinity).frame(height: 300, alignment: .topLeading)
                .background(lcd.gradient, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.black.opacity(0.35), lineWidth: 3))
            }
            Button { scanning = true } label: { Label("SCAN POKÉMON", systemImage: "viewfinder").font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(1).frame(maxWidth: .infinity).padding(20).foregroundStyle(ink).background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 10)).compositingGroup().shadow(color: .black.opacity(0.2), radius: 0, y: 4) }
            HStack { Text("CARDS & SCREEN IMAGES").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1); Spacer(); Link("Data: PokéAPI ↗", destination: URL(string: "https://pokeapi.co")!).font(.caption) }.foregroundStyle(.white.opacity(0.7))
        }
    }
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.caption.monospaced()).opacity(0.6); Spacer(); Text(value).font(.system(.body, design: .monospaced).bold()) }
    }
}

/// Keep UIKit in portrait for both displays. The inner instrument panel is
/// drawn in landscape coordinates without asking iOS to rotate the scene.
private struct FixedInterior<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            let turned = geometry.size.height > geometry.size.width
            content()
                .frame(width: turned ? geometry.size.height : geometry.size.width,
                       height: turned ? geometry.size.width : geometry.size.height)
                .rotationEffect(.degrees(turned ? 90 : 0))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
    }
}
