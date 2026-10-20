import SwiftUI
import UIKit

enum DexAppearance {
    static let shell = Color(red: 0.72, green: 0.075, blue: 0.13)
    static let ink = Color(red: 0.10, green: 0.18, blue: 0.17)
    static let lcd = Color(red: 0.80, green: 0.88, blue: 0.71)
    static let bezel = Color(red: 0.91, green: 0.91, blue: 0.85)
}

struct PhoneDexView: View {
    @ObservedObject var store: DexStore
    @ObservedObject var presentation: DevicePresentation
    @Environment(\.dynamicTypeSize) private var textSize
    @Binding var opened: Bool
    @State private var scanning = false
    @State private var tab = DetailTab.info
    @State private var panel = "Artwork"
    @State private var searchPage = 0
    @State private var keyboardFrame: CGRect?
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { space in
            if space.size.width > space.size.height {
                if opened {
                    let height = PhoneLayoutMetrics.visibleHeight(bounds: space.frame(in: .global), keyboard: keyboardFrame)
                    let metrics = PhoneLayoutMetrics(size: CGSize(width: space.size.width, height: height))
                    VStack(spacing: 8) {
                        toolbar
                        if searchFocused {
                            searchResults
                        } else if textSize.isAccessibilitySize {
                            Picker("Panel", selection: $panel) {
                                Text("Artwork").tag("Artwork")
                                Text("Details").tag("Details")
                            }.pickerStyle(.segmented).frame(height: 44)
                                .accessibilityIdentifier("phonePanelPicker")
                            if panel == "Artwork" { PhoneArtworkPanel(store: store) }
                            else { DexDetails(store: store, tab: $tab) }
                        } else {
                            HStack(spacing: 8) {
                                PhoneArtworkPanel(store: store).frame(width: metrics.panelWidth)
                                RoundedRectangle(cornerRadius: 1).fill(.black.opacity(0.25)).frame(width: 2)
                                    .accessibilityHidden(true)
                                DexDetails(store: store, tab: $tab).frame(width: metrics.panelWidth)
                            }
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(width: space.size.width, height: max(44, height), alignment: .top)
                    .foregroundStyle(DexAppearance.ink)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("phoneInterior")
                } else {
                    PhoneCover(safeAreaInsets: space.safeAreaInsets) { opened = true }.ignoresSafeArea(.container)
                }
            } else {
                VStack(spacing: 12) {
                    if presentation.orientationFailed {
                        Text("Rotate your iPhone to landscape.")
                        Button("Retry landscape") { presentation.requestLandscapeIfNeeded(retry: true) }
                            .frame(minHeight: 44)
                    } else { ProgressView("Preparing landscape…") }
                }.foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(isPresented: $scanning) { ScannerView(store: store, isPresented: $scanning, layout: .phone) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in keyboardFrame = nil }
        .onChange(of: store.query) { _, _ in searchPage = 0 }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { openScanner() } label: {
                HStack(spacing: 7) {
                    Circle().fill(.cyan.gradient).frame(width: 36, height: 36)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                    if !textSize.isAccessibilitySize {
                        HStack(spacing: 3) {
                            ForEach([Color.red, .yellow, .green], id: \.self) { color in
                                Circle().fill(color).frame(width: 7, height: 7).overlay(Circle().stroke(.black.opacity(0.3)))
                            }
                        }
                    }
                }.frame(minWidth: 44, minHeight: 44)
            }.accessibilityLabel("Open Pokémon scanner")
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Search Pokémon…", text: $store.query)
                    .font(.system(size: 14)).frame(minHeight: 44).focused($searchFocused)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.search).accessibilityIdentifier("pokemonSearch")
                    .onSubmit { if let match = store.matches.first { select(match) } }
                Button { store.query = ""; searchFocused = true } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                }.accessibilityLabel("Clear search").opacity(store.query.isEmpty ? 0 : 1).disabled(store.query.isEmpty)
            }.padding(.leading, 10).background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 8))
            Button { if searchFocused { searchFocused = false } else { openScanner() } } label: {
                Text(searchFocused ? "Done" : "Scan").font(.system(size: 14, weight: .semibold))
                    .frame(width: 52, height: 44).background(.cyan.gradient, in: RoundedRectangle(cornerRadius: 8))
            }.accessibilityIdentifier("phoneScan")
            Button {
                searchFocused = false; keyboardFrame = nil; store.query = ""; opened = false
            } label: {
                Text("Cover").font(.system(size: 14, weight: .semibold))
                    .frame(width: 52, height: 44).background(DexAppearance.bezel, in: RoundedRectangle(cornerRadius: 8))
            }.accessibilityIdentifier("phoneCoverButton")
        }.font(.system(size: 14)).frame(height: PhoneLayoutMetrics.toolbarHeight)
    }

    private var searchResults: some View {
        GeometryReader { space in
            let capacity = PhoneLayoutMetrics.resultCapacity(height: space.size.height, maximum: max(1, store.matches.count))
            let pageCount = max(1, (store.matches.count + capacity - 1) / capacity)
            let page = min(searchPage, pageCount - 1)
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 4) {
                    if store.matches.isEmpty {
                        Text(store.query.isEmpty ? "Enter a Pokémon name" : "No matching names")
                            .font(.system(size: 14)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    ForEach(Array(store.matches.dropFirst(page * capacity).prefix(capacity))) { match in
                        Button { select(match) } label: {
                            HStack { Text(match.title); Spacer(); Image(systemName: "arrow.up.left") }
                                .font(.system(size: 14)).padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
                        }.background(DexAppearance.lcd, in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityIdentifier("searchCandidate-\(match.name)")
                    }
                }.frame(maxWidth: .infinity)
                if pageCount > 1 {
                    PhonePageControls(page: $searchPage, count: pageCount, identifier: "search")
                        .frame(width: 132)
                }
            }
        }
    }

    private func select(_ match: Named) {
        searchFocused = false; store.query = ""
        Task { await store.select(match.name) }
    }

    private func openScanner() {
        searchFocused = false; keyboardFrame = nil; scanning = true
    }
}

struct PhoneCover: View {
    var safeAreaInsets = EdgeInsets()
    let open: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.91, green: 0.12, blue: 0.17), DexAppearance.shell], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            GeometryReader { space in
                let w = space.size.width
                let h = space.size.height
                let lens = min(w, h) * 0.25
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.49, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w, y: h * 0.24))
                    }.stroke(Color(red: 0.42, green: 0.03, blue: 0.06), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                    Circle().fill(RadialGradient(colors: [.white, .cyan, .blue], center: .topLeading, startRadius: 0, endRadius: lens))
                        .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 5)).frame(width: lens, height: lens)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 3)
                        .position(x: lens * 0.85, y: lens * 0.72)
                    HStack(spacing: 8) {
                        ForEach([Color.red, .yellow, .green], id: \.self) { color in
                            Circle().fill(color.gradient).frame(width: 10, height: 10).overlay(Circle().stroke(.black.opacity(0.5)))
                        }
                    }.position(x: lens * 1.9, y: lens * 0.45)
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: h * 0.12))
                        .foregroundStyle(.yellow).shadow(color: .black.opacity(0.4), radius: 1, y: 2)
                        .position(x: w * 0.08, y: h * 0.65)
                }
            }.padding(safeAreaInsets)
        }.contentShape(Rectangle()).onTapGesture(perform: open)
            .accessibilityElement(children: .ignore).accessibilityLabel("Closed DexDuo cover")
            .accessibilityHint("Double tap to open").accessibilityAddTraits(.isButton)
            .accessibilityAction { open() }.accessibilityIdentifier("phoneCover")
    }
}

struct PhoneArtworkPanel: View {
    @ObservedObject var store: DexStore

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                Text(store.pokemon.map { String(format: "No. %04d", $0.id) } ?? "CONNECTING")
                    .font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    if let image = store.artworkImage { Image(uiImage: image).resizable().scaledToFit() }
                    else if store.artworkFailed { Image(systemName: "photo").font(.largeTitle) }
                    else { ProgressView() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("pokemonArtwork")
                    .accessibilityLabel(store.pokemon.map { "\($0.title) artwork" } ?? "Pokémon artwork")
                if let pokemon = store.pokemon {
                    Text(pokemon.title.uppercased()).font(.system(size: 20, weight: .black, design: .rounded))
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) { ForEach(pokemon.types, id: \.type.name) { PokemonTypeBadge(name: $0.type.name, fontSize: 14) } }
                }
            }.padding(8).background(DexAppearance.lcd.gradient, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DexAppearance.ink.opacity(0.55), lineWidth: 2))
                .padding(6).background(DexAppearance.bezel, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button { Task { await store.step(-1) } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous Pokémon")
                Spacer()
                if store.loading { ProgressView().tint(.white) }
                Button { Task { await store.step(1) } } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Next Pokémon")
            }.font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).background(DexAppearance.ink, in: RoundedRectangle(cornerRadius: 8)).disabled(store.loading)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("phoneArtworkPanel")
    }
}

struct PhonePageControls: View {
    @Binding var page: Int
    let count: Int
    let identifier: String

    var body: some View {
        HStack(spacing: 0) {
            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .disabled(page <= 0).accessibilityLabel("Previous page").accessibilityIdentifier(identifier + "PreviousPage")
            Text("\(min(page + 1, count))/\(count)").font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity).accessibilityLabel("Page \(min(page + 1, count)) of \(count)")
                .accessibilityIdentifier(identifier + "PageLabel")
            Button { page = min(count - 1, page + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(page >= count - 1).accessibilityLabel("Next page").accessibilityIdentifier(identifier + "NextPage")
        }.font(.system(size: 17, weight: .semibold)).frame(height: 44)
    }
}
