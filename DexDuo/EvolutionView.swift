import SwiftUI

struct EvolutionDiagramLayout {
    static func horizontal(nodeCount: Int, width: CGFloat, fontSize: CGFloat, accessibility: Bool) -> Bool {
        !accessibility && (2...3).contains(nodeCount)
            && width >= CGFloat(nodeCount) * max(70, fontSize * 4.6) + CGFloat(nodeCount - 1) * 52
    }
}

private struct EvolutionAnchors: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}

struct EvolutionView: View {
    @ObservedObject var store: DexStore
    @ObservedObject var model: EvolutionModel
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @State private var method: EvolutionLink?
    @State private var restored = false

    var body: some View {
        VStack(spacing: 0) {
            if let method {
                VStack(alignment: .leading, spacing: 4) {
                    Button { self.method = nil } label: { Label("Back to family", systemImage: "chevron.left").frame(minHeight: 44) }
                        .font(.system(size: 14, weight: .semibold)).accessibilityIdentifier("evolutionBack")
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Evolve into \(method.species.title)").font(.system(size: fontSize, weight: .bold))
                            if method.evolution_details.isEmpty { Text("Evolution requirements are not available.") }
                            ForEach(Array(method.evolution_details.enumerated()), id: \.offset) { index, detail in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("METHOD \(index + 1)" + (detail.isDefault ? " · DEFAULT" : ""))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    ForEach(Array(detail.requirements.enumerated()), id: \.offset) { _, line in Text(line) }
                                    if let version = detail.version { Text("Introduced: \(version)").font(.system(size: 12)) }
                                }
                                Divider()
                            }
                            Text("Conditions can vary by game. Form restrictions are shown when supplied.").font(.system(size: 12))
                        }.font(.system(size: fontSize)).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 6)
                    }.scrollIndicators(.visible).accessibilityIdentifier("evolutionMethodsScroll")
                }
            } else if let chain = model.chain {
                GeometryReader { space in
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 12) {
                                if let error = model.selectionError {
                                    Text(error).font(.system(size: fontSize)).accessibilityIdentifier("evolutionSelectionError")
                                    if let failed = model.failedMember {
                                        Button("Retry selection") { model.choose(failed, store: store) }.frame(minHeight: 44)
                                            .disabled(model.choosing != nil).accessibilityIdentifier("evolutionRetrySelection")
                                    }
                                }
                                Text("Species family · default forms").font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DexAppearance.ink.opacity(0.7))
                                if let linear = chain.chain.linear,
                                   EvolutionDiagramLayout.horizontal(nodeCount: linear.count, width: space.size.width - 6,
                                                                     fontSize: fontSize, accessibility: textSize.isAccessibilitySize) {
                                    HStack(alignment: .center, spacing: 4) {
                                        ForEach(Array(linear.enumerated()), id: \.element.id) { index, link in
                                            if index > 0 { condition(link, horizontal: true).frame(width: 44) }
                                            node(link, column: true).frame(maxWidth: .infinity)
                                        }
                                    }
                                } else {
                                    EvolutionTree(link: chain.chain, model: model, store: store, showMethod: { method = $0 })
                                }
                                if chain.chain.evolves_to.isEmpty {
                                    Text("No known evolutions.").font(.system(size: fontSize)).accessibilityIdentifier("evolutionStandalone")
                                }
                                Text("Tap a Pokémon to open it. Tap an arrow for its evolution methods.")
                                    .font(.system(size: 12)).foregroundStyle(DexAppearance.ink.opacity(0.75))
                            }.padding(.trailing, 6).padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.coordinateSpace(name: "evolutionScroll")
                            .scrollIndicators(.visible).accessibilityIdentifier("evolutionScroll")
                            .onPreferenceChange(EvolutionAnchors.self) { values in
                                if restored { model.scrollAnchor = values.min(by: { abs($0.value) < abs($1.value) })?.key }
                            }
                            .task(id: chain.id) {
                                restored = false
                                let target = model.scrollAnchor ?? store.pokemon?.species.name
                                await Task.yield()
                                guard !Task.isCancelled else { return }
                                if let target { proxy.scrollTo(target, anchor: .top) }
                                await Task.yield()
                                restored = true
                            }
                    }.id(chain.id)
                }
            } else if let error = model.error {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.system(size: fontSize))
                        Button("Retry") { Task { if let species = store.pokemon?.species.name { await model.load(for: species) } } }
                            .frame(minHeight: 44).accessibilityIdentifier("evolutionRetry")
                    }
                }.accessibilityIdentifier("evolutionUnavailable")
            } else {
                ProgressView("Loading evolution family…").font(.system(size: 14)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: store.pokemon?.species.name) { if let species = store.pokemon?.species.name { await model.load(for: species) } }
        .onDisappear { model.cancel() }
        .onChange(of: store.pokemon?.species.name) { _, _ in method = nil }
    }

    private func node(_ link: EvolutionLink, column: Bool) -> some View {
        EvolutionNode(link: link, model: model, store: store, column: column)
    }
    private func condition(_ link: EvolutionLink, horizontal: Bool) -> some View {
        EvolutionCondition(link: link, horizontal: horizontal) { method = link }
    }
}

private struct EvolutionCondition: View {
    let link: EvolutionLink
    var horizontal = false
    let show: () -> Void
    var body: some View {
        Button(action: show) {
            VStack(spacing: 3) {
                Image(systemName: horizontal ? "arrow.right" : "arrow.turn.down.right").font(.system(size: 18))
                Text(link.summary == "Methods…" ? "Methods" : link.summary).font(.system(size: 14)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Evolution methods for \(link.species.title): \(link.summary)")
            .accessibilityIdentifier("evolutionCondition-\(link.id)")
    }
}

private struct EvolutionTree: View {
    let link: EvolutionLink
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    let showMethod: (EvolutionLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EvolutionNode(link: link, model: model, store: store)
            if !link.evolves_to.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(link.evolves_to) { child in
                        HStack(alignment: .top, spacing: 6) {
                            EvolutionCondition(link: child) { showMethod(child) }.frame(width: 62)
                            EvolutionTree(link: child, model: model, store: store, showMethod: showMethod)
                        }
                    }
                }.padding(.leading, 14)
                    .overlay(alignment: .leading) { Rectangle().fill(DexAppearance.ink.opacity(0.25)).frame(width: 1).accessibilityHidden(true) }
            }
        }
    }
}

private struct EvolutionNode: View {
    let link: EvolutionLink
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    var column = false
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    private var selected: Bool { store.pokemon?.species.name == link.id }
    private var number: Int? { link.species.url.split(separator: "/").last.flatMap { Int($0) } }

    var body: some View {
        Button { if !selected { model.choose(link.id, store: store) } } label: {
            Group {
                if column { VStack(spacing: 6) { artwork.frame(height: 72); metadata } }
                else { HStack(spacing: 10) { artwork.frame(width: 48, height: 48); metadata; Spacer(minLength: 0) } }
            }.frame(maxWidth: .infinity, minHeight: 44)
                .padding(column ? 3 : 6)
                .background(.white.opacity(selected ? 0.3 : 0.13), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(selected ? Color.cyan : DexAppearance.ink.opacity(0.25), lineWidth: selected ? 2 : 1))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(model.choosing != nil || store.loading)
            .accessibilityLabel("\(link.species.title), \(number.map { String(format: "number %04d", $0) } ?? "number unavailable")\(selected ? ", selected" : "")")
            .accessibilityValue(model.members[link.id]?.types.map { $0.type.title }.joined(separator: ", ") ?? "Types unavailable")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("evolutionNode-\(link.id)")
            .id(link.id)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: EvolutionAnchors.self, value: [link.id: geometry.frame(in: .named("evolutionScroll")).minY])
            })
    }
    private var artwork: some View {
        Group {
            if let image = model.thumbnails[link.id] { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.system(size: 26)).foregroundStyle(DexAppearance.ink.opacity(0.4)) }
        }.accessibilityHidden(true)
    }
    private var metadata: some View {
        VStack(alignment: column ? .center : .leading, spacing: 3) {
            if let number { Text(String(format: "#%04d", number)).font(.system(size: 10, design: .monospaced)) }
            Text(link.species.title).font(.system(size: fontSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(column ? .center : .leading)
            if let member = model.members[link.id] {
                HStack(spacing: 4) { ForEach(member.types, id: \.type.name) { PokemonTypeBadge(name: $0.type.name, compact: true) } }
            }
            if model.choosing == link.id { ProgressView().controlSize(.small) }
        }
    }
}
