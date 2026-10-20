import SwiftUI
import UIKit

enum PhoneText {
    static func height(_ text: String, width: CGFloat, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize)
        let bounds = (text as NSString).boundingRect(with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        return max(font.lineHeight, bounds.height.rounded(.up)) + 2
    }

    static func pages(_ text: String, width: CGFloat, height: CGFloat, fontSize: CGFloat) -> [String] {
        TextPages.paginate(text) { self.height($0, width: width, fontSize: fontSize) <= height }
    }
}

struct PhoneDetails: View {
    @ObservedObject var store: DexStore
    @Binding var tab: PhoneDetailTab

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(PhoneDetailTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        Text(item.rawValue.uppercased()).font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(tab == item ? Color.cyan : Color(red: 0.16, green: 0.39, blue: 0.52), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(tab == item ? DexAppearance.ink : .white)
                    }.accessibilityIdentifier("detailTab-\(item.rawValue.lowercased())")
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
                    case .info: PhoneInfo(store: store, pokemon: pokemon)
                    case .stats: PhoneStats(pokemon: pokemon)
                    case .types: TypeMatchupsView(defendingTypes: pokemon.types.map { $0.type.name })
                    }
                } else { ProgressView("Loading Pokémon…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DexAppearance.lcd.gradient, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DexAppearance.ink.opacity(0.5), lineWidth: 2))
        }.accessibilityElement(children: .contain).accessibilityIdentifier("phoneDetailsPanel")
    }
}

private struct PhoneInfo: View {
    @ObservedObject var store: DexStore
    let pokemon: Pokemon
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @State private var page = 0

    var body: some View {
        GeometryReader { space in
            let measurementsHeight = UIFont.systemFont(ofSize: fontSize).lineHeight + 14
            let sourceHeight: CGFloat = store.entryVersion.isEmpty ? 0 : 14
            let combinedHeight = space.size.height - measurementsHeight - sourceHeight - 12
            let fitsOnePage = PhoneText.height(store.entryText, width: space.size.width, fontSize: fontSize) <= combinedHeight
            let separateMeasurements = textSize.isAccessibilitySize && !fitsOnePage
            let textHeight = fitsOnePage ? combinedHeight : space.size.height - sourceHeight - 56 - (separateMeasurements ? 0 : measurementsHeight + 6)
            let pages = PhoneText.pages(store.entryText, width: space.size.width,
                                       height: max(UIFont.systemFont(ofSize: fontSize).lineHeight + 2, textHeight), fontSize: fontSize)
            let count = pages.count + (separateMeasurements ? 1 : 0)
            let current = min(page, count - 1)
            VStack(alignment: .leading, spacing: 6) {
                if current < pages.count {
                    Text(pages[current]).font(.system(size: fontSize))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityIdentifier("phoneEntryText")
                    if !store.entryVersion.isEmpty {
                        Text(store.entryVersion.uppercased()).font(.system(size: 11, design: .monospaced))
                            .lineLimit(1).accessibilityLabel("Entry source: \(store.entryVersion)")
                    }
                    if !separateMeasurements { measurements }
                } else {
                    measurements.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if count > 1 { PhonePageControls(page: $page, count: count, identifier: "info") }
            }
        }
        .onChange(of: pokemon.id) { _, _ in page = 0 }
        .onChange(of: store.entryText) { _, _ in page = 0 }
        .onChange(of: textSize) { _, _ in page = 0 }
    }

    private var measurements: some View {
        HStack(alignment: .top, spacing: 12) {
            measurement("Height", String(format: "%.1f m", Double(pokemon.height) / 10))
            measurement("Weight", String(format: "%.1f kg", Double(pokemon.weight) / 10))
        }
    }

    private func measurement(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased()).font(.system(size: 11, design: .monospaced))
            Text(value).font(.system(size: fontSize, weight: .semibold, design: .monospaced))
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

private struct PhoneStats: View {
    let pokemon: Pokemon
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @State private var page = 0

    var body: some View {
        GeometryReader { space in
            let rowHeight = max(20, UIFont.systemFont(ofSize: fontSize).lineHeight + 2)
            let statsHeight = CGFloat(pokemon.stats.count) * (rowHeight + 2) - 2
            let abilities = pokemon.abilities.map { $0.ability.title }.joined(separator: " · ")
            let abilitiesHeight = PhoneText.height(abilities, width: space.size.width, fontSize: fontSize)
            let combined = statsHeight + 22 + 16 + abilitiesHeight + 18 <= space.size.height
            let capacity = max(1, Int((space.size.height - 78) / (rowHeight + 2)))
            let statPageCount = max(1, (pokemon.stats.count + capacity - 1) / capacity)
            let abilityPages = PhoneText.pages(abilities, width: space.size.width,
                                              height: max(rowHeight, space.size.height - 72), fontSize: fontSize)
            let count = combined ? 1 : statPageCount + abilityPages.count
            let current = min(page, count - 1)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    if combined || current < statPageCount {
                        VStack(spacing: 2) {
                            ForEach(Array(pokemon.stats.dropFirst(combined ? 0 : current * capacity).prefix(combined ? pokemon.stats.count : capacity)), id: \.stat.name) { stat in
                                statRow(stat).frame(height: rowHeight)
                            }
                        }
                        HStack {
                            Text("BASE TOTAL").font(.system(size: 12, weight: .bold, design: .monospaced))
                            Spacer()
                            Text("\(pokemon.baseStatTotal)").font(.system(size: 14, weight: .bold, design: .monospaced))
                        }.frame(height: 22).accessibilityElement(children: .combine)
                        if combined { abilityText(abilities) }
                    } else {
                        abilityText(abilityPages[current - statPageCount])
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if count > 1 { PhonePageControls(page: $page, count: count, identifier: "stats") }
            }
        }.onChange(of: pokemon.id) { _, _ in page = 0 }
            .onChange(of: fontSize) { _, _ in page = 0 }
    }

    private func abilityText(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ABILITIES").font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(text).font(.system(size: fontSize)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("phoneAbilities")
        }
    }

    private func statRow(_ stat: Pokemon.Stat) -> some View {
        let title = ["hp": "HP", "attack": "Attack", "defense": "Defense", "special-attack": "Sp. Atk", "special-defense": "Sp. Def", "speed": "Speed"][stat.stat.name] ?? stat.stat.title
        return HStack(spacing: 6) {
            Text(title).font(.system(size: fontSize, design: .monospaced))
                .frame(width: fontSize * 4.6, alignment: .leading)
            ProgressView(value: Double(stat.base_stat), total: 255).tint(DexAppearance.ink).accessibilityHidden(true)
            Text("\(stat.base_stat)").font(.system(size: fontSize, design: .monospaced)).frame(width: fontSize * 2.2, alignment: .trailing)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(stat.stat.title), \(stat.base_stat)")
    }
}
