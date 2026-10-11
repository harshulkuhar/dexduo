import Foundation
@main struct EntryCheck {
    static func main() async throws {
        let p = try await DexAPI.shared.get("pokemon/espeon", as: Pokemon.self)
        precondition(p.baseStatTotal == 525)
        let s = try await DexAPI.shared.get("pokemon-species/\(p.species.name)", as: Species.self)
        precondition(s.englishEntry != nil)
        precondition(!s.englishEntry!.cleanedText.contains("\n"))
        print("PASS: Espeon total 525; English entry decoded and cleaned")
    }
}
