import SwiftUI

struct DexDetails: View {
    @ObservedObject var store: DexStore
    @Binding var tab: DetailTab
    @EnvironmentObject private var evolution: EvolutionModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(DetailTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Text(item.title).font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(tab == item ? Color.cyan : Color(red: 0.16, green: 0.39, blue: 0.52), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(tab == item ? DexAppearance.ink : .white)
                    }.accessibilityIdentifier("detailTab-\(item.rawValue)")
                        .accessibilityLabel(item.rawValue.capitalized)
                        .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
            }
            Group {
                if let error = store.error {
                    VStack(spacing: 8) {
                        Text(error).font(.system(size: 14))
                        Button("Retry") { Task { await store.start() } }.frame(minHeight: 44)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pokemon = store.pokemon {
                    switch tab {
                    case .info: DexInfo(store: store, pokemon: pokemon).id(pokemon.id)
                    case .stats: DexStats(pokemon: pokemon).id(pokemon.id)
                    case .types: TypeMatchupsView(defendingTypes: pokemon.types.map { $0.type.name })
                    case .evolution: EvolutionView(store: store, model: evolution)
                    }
                } else { ProgressView("Loading Pokémon…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DexAppearance.lcd.gradient, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DexAppearance.ink.opacity(0.5), lineWidth: 2))
        }.foregroundStyle(DexAppearance.ink)
            .accessibilityElement(children: .contain).accessibilityIdentifier("phoneDetailsPanel")
    }
}

private struct DexInfo: View {
    @ObservedObject var store: DexStore
    let pokemon: Pokemon
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.entryText).font(.system(size: fontSize))
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("phoneEntryText")
                if !store.entryVersion.isEmpty {
                    Text(store.entryVersion.uppercased()).font(.system(size: 11, design: .monospaced))
                        .accessibilityLabel("Entry source: \(store.entryVersion)")
                }
                HStack(alignment: .top, spacing: 12) {
                    measurement("Height", String(format: "%.1f m", Double(pokemon.height) / 10))
                    measurement("Weight", String(format: "%.1f kg", Double(pokemon.weight) / 10))
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 6).padding(.bottom, 4)
        }.scrollIndicators(.visible).accessibilityIdentifier("infoScroll")
    }
    private func measurement(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.system(size: 11, design: .monospaced))
            Text(value).font(.system(size: fontSize, weight: .semibold, design: .monospaced))
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
            .accessibilityIdentifier("pokemon\(title)")
    }
}

private struct DexStats: View {
    let pokemon: Pokemon
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 6) {
                    ForEach(pokemon.stats, id: \.stat.name) { stat in
                        HStack(spacing: 6) {
                            Text(statTitle(stat.stat.name)).frame(width: fontSize * 4.6, alignment: .leading)
                            ProgressView(value: Double(stat.base_stat), total: 255).tint(DexAppearance.ink).accessibilityHidden(true)
                            Text("\(stat.base_stat)").frame(width: fontSize * 2.2, alignment: .trailing)
                        }.font(.system(size: fontSize, design: .monospaced))
                            .accessibilityElement(children: .ignore).accessibilityLabel("\(stat.stat.title), \(stat.base_stat)")
                    }
                }
                HStack {
                    Text("BASE TOTAL").font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    Text("\(pokemon.baseStatTotal)").font(.system(size: fontSize, weight: .bold, design: .monospaced))
                }.accessibilityElement(children: .combine).accessibilityIdentifier("baseStatTotal")
                Divider()
                Text("ABILITIES").font(.system(size: 12, weight: .bold, design: .monospaced))
                Text(pokemon.abilities.map { $0.ability.title }.joined(separator: " · "))
                    .font(.system(size: fontSize)).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("phoneAbilities")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 6).padding(.bottom, 4)
        }.scrollIndicators(.visible).accessibilityIdentifier("statsScroll")
    }
    private func statTitle(_ name: String) -> String {
        ["hp": "HP", "attack": "Attack", "defense": "Defense", "special-attack": "Sp. Atk", "special-defense": "Sp. Def", "speed": "Speed"][name] ?? name.capitalized
    }
}
