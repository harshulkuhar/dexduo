import SwiftUI

private struct EvolutionAnchors: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}

struct EvolutionView: View {
    @ObservedObject var store: DexStore
    @ObservedObject var model: EvolutionModel
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @State private var restored = false

    var body: some View {
        VStack(spacing: 0) {
            if let chain = model.chain {
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
                            EvolutionTree(link: chain.chain, model: model, store: store)
                            if chain.chain.evolves_to.isEmpty {
                                Text("No known evolutions.").font(.system(size: fontSize)).accessibilityIdentifier("evolutionStandalone")
                            }
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
    }
}

private struct EvolutionCondition: View {
    let link: EvolutionLink
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.down").font(.system(size: 18)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(link.conditions.enumerated()), id: \.offset) { index, condition in
                    if index > 0 {
                        Text("or").foregroundStyle(DexAppearance.ink.opacity(0.7))
                    }
                    Text(condition).fixedSize(horizontal: false, vertical: true)
                }
            }.font(.system(size: fontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Evolve into \(link.species.title): " + link.conditions.joined(separator: "; or "))
            .accessibilityIdentifier("evolutionCondition-\(link.id)")
    }
}

private struct EvolutionTree: View {
    let link: EvolutionLink
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EvolutionNode(link: link, model: model, store: store)
            if !link.evolves_to.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(link.evolves_to) { child in
                        VStack(alignment: .leading, spacing: 8) {
                            EvolutionCondition(link: child)
                            EvolutionTree(link: child, model: model, store: store)
                        }
                    }
                }.padding(.leading, link.evolves_to.count > 1 ? 12 : 0)
                    .overlay(alignment: .leading) {
                        if link.evolves_to.count > 1 {
                            Rectangle().fill(DexAppearance.ink.opacity(0.25)).frame(width: 1).accessibilityHidden(true)
                        }
                    }
            }
        }
    }
}

private struct EvolutionNode: View {
    let link: EvolutionLink
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    private var selected: Bool { store.pokemon?.species.name == link.id }
    private var number: Int? { link.species.url.split(separator: "/").last.flatMap { Int($0) } }

    var body: some View {
        Button { if !selected { model.choose(link.id, store: store) } } label: {
            HStack(spacing: 10) {
                artwork.frame(width: 56, height: 56)
                metadata
                Spacer(minLength: 0)
            }.frame(maxWidth: .infinity, minHeight: 44)
                .padding(6)
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
        VStack(alignment: .leading, spacing: 3) {
            if let number { Text(String(format: "#%04d", number)).font(.system(size: 10, design: .monospaced)) }
            Text(link.species.title).font(.system(size: fontSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            if let member = model.members[link.id] {
                HStack(spacing: 4) { ForEach(member.types, id: \.type.name) { PokemonTypeBadge(name: $0.type.name, compact: true) } }
            }
            if model.choosing == link.id { ProgressView().controlSize(.small) }
        }
    }
}
