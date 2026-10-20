import SwiftUI

private struct EvolutionAnchors: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { $1 }) }
}

private struct EvolutionNodeBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct EvolutionBranchLines: Shape {
    let junctions: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let last = junctions.map(\.y).max() else { return path }
        let trunk: CGFloat = 12
        path.move(to: CGPoint(x: trunk, y: 0))
        path.addLine(to: CGPoint(x: trunk, y: last))
        for point in junctions {
            path.move(to: CGPoint(x: trunk, y: point.y)); path.addLine(to: point)
            path.move(to: CGPoint(x: point.x - 4, y: point.y - 4))
            path.addLine(to: point); path.addLine(to: CGPoint(x: point.x - 4, y: point.y + 4))
        }
        return path
    }
}

// The caption sits above the shaft; the destination card is centered on its tip.
struct EvolutionForkRow: Layout {
    let gutter: CGFloat

    static func gutter(lcdWidth: CGFloat, preferred: CGFloat = 132) -> CGFloat {
        max(48, min(preferred, lcdWidth * 0.45, lcdWidth - 160))
    }
    static func frames(width: CGFloat, gutter: CGFloat, captionHeight: CGFloat, cardHeight: CGFloat) -> (caption: CGRect, card: CGRect) {
        let junction = max(cardHeight / 2, captionHeight + 6)
        return (
            CGRect(x: 16, y: junction - captionHeight - 6, width: gutter - 20, height: captionHeight),
            CGRect(x: gutter, y: junction - cardHeight / 2, width: max(0, width - gutter), height: cardHeight)
        )
    }
    private func frames(width: CGFloat, subviews: Subviews) -> (caption: CGRect, card: CGRect) {
        Self.frames(width: width, gutter: gutter,
                    captionHeight: subviews[0].sizeThatFits(.init(width: gutter - 20, height: nil)).height,
                    cardHeight: subviews[1].sizeThatFits(.init(width: width - gutter, height: nil)).height)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: width, height: max(frames.caption.maxY, frames.card.maxY))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(width: bounds.width, subviews: subviews)
        for (view, frame) in zip(subviews, [frames.caption, frames.card]) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

struct EvolutionView: View {
    @ObservedObject var store: DexStore
    @ObservedObject var model: EvolutionModel
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var preferredGutter: CGFloat = 132
    @State private var restored = false

    var body: some View {
        VStack(spacing: 0) {
            if let chain = model.chain {
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
                                EvolutionTree(link: chain.tree, model: model, store: store,
                                              indentation: EvolutionForkRow.gutter(lcdWidth: space.size.width - 6, preferred: preferredGutter))
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
                                let selected = chain.tree.flattened.first {
                                    $0.id == store.pokemon?.name || model.members[$0.id]?.name == store.pokemon?.name
                                }?.id
                                let target = model.scrollAnchor ?? selected ?? store.pokemon?.species.name
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
        .task(id: store.pokemon?.name) { if let species = store.pokemon?.species.name { await model.load(for: species) } }
        .onDisappear { model.cancel() }
    }
}

private struct EvolutionCondition: View {
    let link: EvolutionBranch
    var direct = false
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if direct { Image(systemName: "arrow.down").font(.system(size: 18)).accessibilityHidden(true) }
            Text(link.conditionText)
                .font(.system(size: fontSize)).fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(direct ? .leading : .center)
                .frame(maxWidth: .infinity, alignment: direct ? .leading : .center)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Evolve into \(link.title): \(link.conditionText)")
            .accessibilityIdentifier("evolutionCondition-\(link.id)")
    }
}

private struct EvolutionTree: View {
    let link: EvolutionBranch
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    let indentation: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EvolutionNode(link: link, model: model, store: store)
            EvolutionChildren(link: link, model: model, store: store, indentation: indentation)
        }
    }
}

private struct EvolutionChildren: View {
    let link: EvolutionBranch
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    let indentation: CGFloat

    var body: some View {
        if link.children.count == 1, let child = link.children.first {
            VStack(alignment: .leading, spacing: 8) {
                EvolutionCondition(link: child, direct: true)
                EvolutionTree(link: child, model: model, store: store, indentation: indentation)
            }.padding(.top, 8)
        } else if !link.children.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(link.children) { child in
                    VStack(alignment: .leading, spacing: 0) {
                        EvolutionForkRow(gutter: indentation) {
                            EvolutionCondition(link: child)
                            EvolutionNode(link: child, model: model, store: store)
                        }
                        EvolutionChildren(link: child, model: model, store: store, indentation: indentation)
                            .padding(.leading, indentation)
                    }
                }
            }.padding(.top, 8)
                .overlayPreferenceValue(EvolutionNodeBounds.self) { bounds in
                    GeometryReader { geometry in
                        // Immediate children share this trunk; descendants draw their own connectors.
                        let junctions = link.children.compactMap { child -> CGPoint? in
                            guard let anchor = bounds[child.id] else { return nil }
                            let card = geometry[anchor]
                            return CGPoint(x: card.minX - 3, y: card.midY)
                        }
                        EvolutionBranchLines(junctions: junctions)
                            .stroke(DexAppearance.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
        }
    }
}

private struct EvolutionNode: View {
    let link: EvolutionBranch
    @ObservedObject var model: EvolutionModel
    @ObservedObject var store: DexStore
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    private var selected: Bool {
        store.pokemon?.name == (model.members[link.id]?.name ?? link.id)
    }
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
            .accessibilityLabel("\(link.title), \(number.map { String(format: "number %04d", $0) } ?? "number unavailable")\(selected ? ", selected" : "")")
            .accessibilityValue(model.members[link.id]?.types.map { $0.type.title }.joined(separator: ", ") ?? "Types unavailable")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("evolutionNode-\(link.id)")
            .id(link.id)
            .anchorPreference(key: EvolutionNodeBounds.self, value: .bounds) { [link.id: $0] }
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
            Text(link.title).font(.system(size: fontSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
            if let member = model.members[link.id] {
                HStack(spacing: 4) { ForEach(member.types, id: \.type.name) { PokemonTypeBadge(name: $0.type.name, compact: true) } }
            }
            if model.choosing == link.id { ProgressView().controlSize(.small) }
        }
    }
}
