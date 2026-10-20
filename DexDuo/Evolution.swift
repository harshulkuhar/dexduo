import Foundation
import SwiftUI

struct APIReference: Decodable, Sendable { let url: String }

struct EvolutionChain: Decodable, Sendable {
    let id: Int
    let chain: EvolutionLink
}

struct EvolutionLink: Decodable, Sendable, Identifiable {
    let species: Named
    let evolution_details: [EvolutionMethod]
    let evolves_to: [EvolutionLink]
    var id: String { species.name }
    var flattened: [EvolutionLink] { [self] + evolves_to.flatMap(\.flattened) }
    var linear: [EvolutionLink]? {
        guard evolves_to.count <= 1 else { return nil }
        guard let child = evolves_to.first else { return [self] }
        return child.linear.map { [self] + $0 }
    }
    var summary: String {
        let defaults = evolution_details.filter { $0.isDefault }
        let methods = defaults.isEmpty ? evolution_details : defaults
        let summaries = Set(methods.map(\.shortSummary))
        return summaries.count == 1 ? summaries.first! : "Methods…"
    }
}

// Retain new/non-null API requirements so an unrecognized field cannot silently
// turn a conditional evolution into a generic level-up claim.
indirect enum EvolutionValue: Decodable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([EvolutionValue]), object([String: EvolutionValue])
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let flag = try? value.decode(Bool.self) { self = .bool(flag) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let text = try? value.decode(String.self) { self = .string(text) }
        else if let list = try? value.decode([EvolutionValue].self) { self = .array(list) }
        else { self = .object(try value.decode([String: EvolutionValue].self)) }
    }
    var text: String? { if case .string(let value) = self { return value }; return nil }
    var number: Double? { if case .number(let value) = self { return value }; return nil }
    var flag: Bool { if case .bool(let value) = self { return value }; return false }
    var object: [String: EvolutionValue] { if case .object(let value) = self { return value }; return [:] }
    var list: [EvolutionValue] { if case .array(let value) = self { return value }; return [] }
    var named: String? { object["name"]?.text.map { $0.replacingOccurrences(of: "-", with: " ").capitalized } }
    var hasRequirement: Bool {
        switch self {
        case .null: return false
        case .bool(let value): return value
        case .string(let value): return !value.isEmpty
        case .array(let value): return !value.isEmpty
        case .object(let value): return !value.isEmpty
        case .number: return true
        }
    }
}

struct EvolutionMethod: Decodable, Sendable {
    let fields: [String: EvolutionValue]
    init(from decoder: Decoder) throws { fields = try decoder.singleValueContainer().decode([String: EvolutionValue].self) }
    var isDefault: Bool { fields["is_default"]?.flag == true }
    private var trigger: String { fields["trigger"]?.object["name"]?.text ?? "" }
    private static let triggers = ["level-up": "Level up", "trade": "Trade", "use-item": "Use item", "shed": "Shed",
                                   "spin": "Spin", "tower-of-darkness": "Tower of Darkness", "tower-of-waters": "Tower of Waters",
                                   "three-critical-hits": "Land three critical hits", "take-damage": "Take damage", "agile-style-move": "Use an agile-style move",
                                   "strong-style-move": "Use a strong-style move", "recoil-damage": "Take recoil damage"]
    private static let known: Set<String> = ["trigger", "is_default", "version_group", "item", "gender", "held_item", "known_move", "known_move_type",
        "location", "min_level", "min_happiness", "min_beauty", "min_affection", "near_special_rock", "needs_multiplayer", "needs_overworld_rain",
        "party_species", "party_type", "relative_physical_stats", "time_of_day", "trade_species", "turn_upside_down", "region", "required_pokemon_form",
        "evolved_pokemon_form", "used_move", "min_move_count", "min_steps", "min_damage_taken", "allowed_natures", "condition_expression"]
    var hasUnresolvedRequirements: Bool {
        Self.triggers[trigger] == nil || fields.contains { !Self.known.contains($0.key) && $0.value.hasRequirement }
            || fields["condition_expression"]?.hasRequirement == true
    }
    var requirements: [String] {
        var lines: [String] = []
        if trigger == "use-item", let item = fields["item"]?.named { lines.append("Use \(item)") }
        else if trigger == "level-up", let level = fields["min_level"]?.number { lines.append("Level \(Int(level))") }
        else { lines.append(Self.triggers[trigger] ?? "Special evolution") }
        if trigger != "use-item", let item = fields["item"]?.named { lines.append("Item: \(item)") }
        if trigger != "level-up", let level = fields["min_level"]?.number { lines.append("Minimum level: \(Int(level))") }
        for (key, title) in [("held_item", "Holding"), ("known_move", "Knows"), ("known_move_type", "Knows a move of type"),
                             ("location", "Location"), ("party_species", "Party member"), ("party_type", "Party type"),
                             ("trade_species", "Trade for"), ("region", "Region"), ("required_pokemon_form", "Required form"),
                             ("evolved_pokemon_form", "Resulting form"), ("used_move", "Use move")] {
            if let value = fields[key]?.named { lines.append("\(title): \(value)") }
        }
        for (key, title) in [("min_happiness", "Friendship"), ("min_affection", "Affection"), ("min_beauty", "Beauty"),
                             ("min_move_count", "Move uses"), ("min_steps", "Steps"), ("min_damage_taken", "Damage taken")] {
            if let value = fields[key]?.number { lines.append("\(title) ≥ \(Int(value))") }
        }
        if let time = fields["time_of_day"]?.text, !time.isEmpty { lines.append("Time: \(time.replacingOccurrences(of: "-", with: " ").capitalized)") }
        if let gender = fields["gender"]?.number { lines.append("Gender: \(gender == 1 ? "Female" : gender == 2 ? "Male" : "Unresolved")") }
        if let relation = fields["relative_physical_stats"]?.number {
            lines.append(relation == 1 ? "Attack > Defense" : relation == -1 ? "Attack < Defense" : relation == 0 ? "Attack = Defense" : "Stat requirement unresolved")
        }
        for (key, title) in [("near_special_rock", "Near the specified special rock"), ("needs_multiplayer", "Multiplayer required"),
                             ("needs_overworld_rain", "Overworld rain required"), ("turn_upside_down", "Turn the device upside down")] {
            if fields[key]?.flag == true { lines.append(title) }
        }
        let natures = fields["allowed_natures"]?.list.compactMap(\.named) ?? []
        if !natures.isEmpty { lines.append("Allowed natures: " + natures.joined(separator: ", ")) }
        if let chance = fields["condition_expression"]?.object["percentage_chance"]?.number { lines.append("Intrinsic condition: \(chance.formatted())% outcome") }
        if hasUnresolvedRequirements { lines.append("Additional requirements are not fully described here.") }
        return lines
    }
    var version: String? { fields["version_group"]?.named }
    var shortSummary: String {
        guard !hasUnresolvedRequirements else { return "Methods…" }
        // Ordinary required-form references still appear in full method details.
        let formID = fields["required_pokemon_form"]?.object["url"]?.text.flatMap { URL(string: $0)?.lastPathComponent }.flatMap(Int.init)
        let simple = requirements.filter { line in
            !(line.hasPrefix("Required form:") && formID.map { $0 < 10000 } == true)
        }
        return simple.count == 1 && simple[0].count <= 24 ? simple[0] : "Methods…"
    }
}

enum EvolutionError: Error { case unavailable, defaultVarietyMissing }

protocol EvolutionFetching: Sendable {
    func family(for species: String) async throws -> EvolutionChain
    func member(for species: String) async throws -> Pokemon
}

actor EvolutionRepository: EvolutionFetching {
    static let shared = EvolutionRepository()
    private let api: any DexFetching
    private var families: [String: EvolutionChain] = [:]
    private var chains: [String: Task<EvolutionChain, Error>] = [:]
    private var members: [String: Task<Pokemon, Error>] = [:]
    init(api: any DexFetching = DexAPI.shared) { self.api = api }

    func family(for species: String) async throws -> EvolutionChain {
        if let value = families[species] { return value }
        let details = try await api.get("pokemon-species/\(species)", as: Species.self)
        guard let url = details.evolution_chain?.url, let components = URLComponents(string: url),
              components.host == "pokeapi.co", components.path.hasPrefix("/api/v2/evolution-chain/"),
              let identifier = components.path.split(separator: "/").last, Int(identifier) != nil else { throw EvolutionError.unavailable }
        let path = "evolution-chain/\(identifier)"
        let task: Task<EvolutionChain, Error>
        if let existing = chains[path] { task = existing }
        else { let api = api; task = Task { try await api.get(path, as: EvolutionChain.self) }; chains[path] = task }
        do {
            let value = try await task.value
            for link in value.chain.flattened { families[link.id] = value }
            return value
        } catch { chains[path] = nil; throw error }
    }

    func member(for species: String) async throws -> Pokemon {
        if let existing = members[species] { return try await existing.value }
        let api = api
        let task = Task {
            let details = try await api.get("pokemon-species/\(species)", as: Species.self)
            guard let variety = details.varieties?.first(where: \.is_default)?.pokemon.name else { throw EvolutionError.defaultVarietyMissing }
            return try await api.get("pokemon/\(variety)", as: Pokemon.self)
        }
        members[species] = task
        do { return try await task.value }
        catch { members[species] = nil; throw error }
    }
}

@MainActor final class EvolutionModel: ObservableObject {
    @Published private(set) var chain: EvolutionChain?
    @Published private(set) var members: [String: Pokemon] = [:]
    @Published private(set) var thumbnails: [String: UIImage] = [:]
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var choosing: String?
    @Published private(set) var failedMember: String?
    @Published private(set) var selectionError: String?
    var scrollAnchor: String?
    private let repository: any EvolutionFetching
    private let thumbnail: @Sendable (URL) async throws -> UIImage
    private let imageCache = NSCache<NSURL, UIImage>()
    private var loadGeneration = UUID()
    private var selectionGeneration = UUID()
    private var selectionTask: Task<Void, Never>?

    init(repository: any EvolutionFetching = EvolutionRepository.shared,
         thumbnail: @escaping @Sendable (URL) async throws -> UIImage = { url in
             let data = try await ArtworkDiskCache.shared.data(for: url)
             guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
             return await image.byPreparingThumbnail(ofSize: CGSize(width: 160, height: 160)) ?? image
         }) {
        self.repository = repository; self.thumbnail = thumbnail
        imageCache.totalCostLimit = 32 * 1024 * 1024
    }

    func load(for species: String) async {
        let token = UUID(); loadGeneration = token
        if let choosing, choosing != species { cancelSelection() }
        let sameFamily = chain?.chain.flattened.contains { $0.id == species } == true
        if !sameFamily { chain = nil; members = [:]; thumbnails = [:]; scrollAnchor = nil; selectionError = nil; failedMember = nil }
        loading = !sameFamily; error = nil
        do {
            let value = try await repository.family(for: species)
            guard loadGeneration == token, !Task.isCancelled else { return }
            if chain?.id != value.id { scrollAnchor = nil }
            chain = value; loading = false
            let links = value.chain.flattened
            for start in stride(from: 0, to: links.count, by: 4) {
                guard loadGeneration == token, !Task.isCancelled else { return }
                await withTaskGroup(of: (String, Pokemon?).self) { group in
                    for link in links[start..<min(start + 4, links.count)] where members[link.id] == nil {
                        let repository = repository
                        group.addTask { (link.id, try? await repository.member(for: link.id)) }
                    }
                    for await (name, member) in group {
                        guard loadGeneration == token, !Task.isCancelled, let member else { continue }
                        members[name] = member
                    }
                }
            }
            for start in stride(from: 0, to: links.count, by: 4) {
                guard loadGeneration == token, !Task.isCancelled else { return }
                await withTaskGroup(of: (String, UIImage?).self) { group in
                    for link in links[start..<min(start + 4, links.count)] where thumbnails[link.id] == nil {
                        guard let url = members[link.id]?.artwork else { continue }
                        if let image = imageCache.object(forKey: url as NSURL) { thumbnails[link.id] = image; continue }
                        let thumbnail = thumbnail
                        group.addTask { (link.id, try? await thumbnail(url)) }
                    }
                    for await (name, image) in group {
                        guard loadGeneration == token, !Task.isCancelled, let image else { continue }
                        thumbnails[name] = image
                        if let url = members[name]?.artwork { imageCache.setObject(image, forKey: url as NSURL, cost: 160 * 160 * 4) }
                    }
                }
            }
        } catch {
            guard loadGeneration == token, !Task.isCancelled else { return }
            loading = false; self.error = "Evolution data is unavailable. Connect to the internet and retry; saved families work offline."
        }
    }

    func choose(_ species: String, store: DexStore) {
        guard choosing == nil else { return }
        choosing = species; selectionError = nil; failedMember = nil
        let token = UUID(); selectionGeneration = token
        selectionTask = Task {
            do {
                let member = try await repository.member(for: species)
                guard selectionGeneration == token, !Task.isCancelled else { return }
                let success = await store.select(member.name, reportError: false)
                guard selectionGeneration == token, !Task.isCancelled else { return }
                choosing = nil
                if !success { selectionFailed(species) }
            } catch {
                guard selectionGeneration == token, !Task.isCancelled else { return }
                choosing = nil; selectionFailed(species)
            }
        }
    }
    private func selectionFailed(_ species: String) {
        failedMember = species
        selectionError = "Couldn’t load \(species.replacingOccurrences(of: "-", with: " ").capitalized). Your previous selection is retained."
    }
    private func cancelSelection() {
        selectionGeneration = UUID(); selectionTask?.cancel(); selectionTask = nil; choosing = nil
    }
    func cancel() { loadGeneration = UUID(); cancelSelection(); loading = false }
}
