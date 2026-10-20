import SwiftUI

struct TypeMatchupsView: View {
    let defendingTypes: [String]

    var body: some View {
        if let matchups = try? TypeChart.bundled.get().matchups(defending: defendingTypes) {
            VStack(spacing: 8) {
                HStack {
                    Text("Type-only damage")
                        .accessibilityHint("Abilities, items and battle effects are excluded.")
                    Spacer(minLength: 4)
                    Text("Blank = 1×")
                }.font(.system(size: 11, design: .monospaced))
                GeometryReader { space in
                    if let arrangement = TypeGridArrangement.fitting(in: space.size) {
                        let gap = TypeGridArrangement.gap
                        let width = (space.size.width - CGFloat(arrangement.columns - 1) * gap) / CGFloat(arrangement.columns)
                        let height = (space.size.height - CGFloat(arrangement.rows - 1) * gap) / CGFloat(arrangement.rows)
                        VStack(spacing: gap) {
                            ForEach(0..<arrangement.rows, id: \.self) { row in
                                HStack(spacing: gap) {
                                    ForEach(0..<arrangement.columns, id: \.self) { column in
                                        TypeMatchupTile(matchup: matchups[row * arrangement.columns + column])
                                            .frame(width: width, height: height)
                                    }
                                }
                            }
                        }.accessibilityElement(children: .contain)
                            .accessibilityIdentifier("typeGrid")
                    } else {
                        Text("More space is needed to show all 18 types.")
                            .font(.footnote).frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        } else {
            Text("Type matchups unavailable for this Pokémon.")
                .font(.footnote).frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("typeChartUnavailable")
        }
    }
}

private struct TypeMatchupTile: View {
    let matchup: TypeMatchup

    var body: some View {
        VStack(spacing: 0) {
            Text(matchup.type.abbreviation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TypePalette.color(matchup.type.rgb))
                .foregroundStyle(TypePalette.foreground(matchup.type.rgb))
            Text(matchup.effectiveness.text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TypePalette.color(matchup.effectiveness.rgb))
                .foregroundStyle(TypePalette.foreground(matchup.effectiveness.rgb))
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(matchup.type.title), \(matchup.effectiveness.spokenValue)")
        .accessibilityIdentifier("typeMatchup-\(matchup.type.rawValue)")
    }
}

struct PokemonTypeBadge: View {
    let name: String
    var fontSize: CGFloat = 10

    var body: some View {
        let rgb = PokemonType(rawValue: name)?.rgb ?? 0xAAAA99
        Text(name.uppercased())
            .font(.system(size: fontSize, weight: .bold, design: .monospaced)).tracking(2)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(TypePalette.color(rgb), in: Capsule())
            .foregroundStyle(TypePalette.foreground(rgb))
            .accessibilityLabel("\(name.capitalized) type")
            .accessibilityIdentifier("pokemonType-\(name)")
    }
}

enum TypePalette {
    static func color(_ rgb: UInt32) -> Color {
        Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
              green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: 1)
    }

    static func foreground(_ rgb: UInt32) -> Color {
        let channels = [rgb >> 16, rgb >> 8, rgb].map { value -> Double in
            let channel = Double(value & 255) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        return luminance > 0.179 ? .black : .white
    }
}
