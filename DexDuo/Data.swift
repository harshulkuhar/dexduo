import Foundation
import SwiftUI
import CryptoKit
import Combine

struct Named: Decodable, Identifiable, Sendable {
    let name: String
    let url: String
    var id: String { name }
    var title: String { name.replacingOccurrences(of: "-", with: " ").capitalized }
}
struct IndexResponse: Decodable, Sendable { let results: [Named] }
struct Pokemon: Decodable, Sendable {
    let id: Int
    let name: String
    let height: Int
    let weight: Int
    let types: [Kind]
    let abilities: [Ability]
    let stats: [Stat]
    let species: Named
    var baseStatTotal: Int { stats.reduce(0) { $0 + $1.base_stat } }
    let sprites: Sprites
    struct Kind: Decodable, Sendable { let type: Named }
    struct Ability: Decodable, Sendable { let ability: Named }
    struct Stat: Decodable, Sendable { let base_stat: Int; let stat: Named }
    struct Sprites: Decodable, Sendable {
        let front_default: String?
        let other: [String: Artwork]?
    }
    struct Artwork: Decodable, Sendable { let front_default: String? }
    var title: String { name.replacingOccurrences(of: "-", with: " ").capitalized }
    var artwork: URL? {
        guard let path = sprites.other?["official-artwork"]?.front_default ?? sprites.front_default, !path.isEmpty else { return nil }
        return URL(string: path)
    }
}

struct Species: Decodable, Sendable {
    let flavor_text_entries: [Entry]
    let evolution_chain: APIReference?
    let varieties: [Variety]?
    struct Variety: Decodable, Sendable { let is_default: Bool; let pokemon: Named }
    struct Entry: Decodable, Sendable {
        let flavor_text: String
        let language: Named
        let version: Named
        var cleanedText: String { flavor_text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    }
    var englishEntry: Entry? { flavor_text_entries.last { $0.language.name == "en" } }
}

protocol DexFetching: Sendable {
    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T
}

actor DexAPI: DexFetching {
    static let shared = DexAPI()
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DexDuoData")
    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        let file = directory.appendingPathComponent(path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "?", with: "_"))
        if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data),
           let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(modified) < 86400 * 7 { return value }
        do {
            let (data, response) = try await URLSession.shared.data(from: URL(string: "https://pokeapi.co/api/v2/\(path)")!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let value = try JSONDecoder().decode(T.self, from: data)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return value
        } catch {
            if let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(T.self, from: data) { return value }
            throw error
        }
    }
}

func normalized(_ string: String) -> String {
    string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        .replacingOccurrences(of: "♀", with: "f").replacingOccurrences(of: "♂", with: "m")
        .filter { $0.isLetter || $0.isNumber }
}

@MainActor final class DexStore: ObservableObject {
    @Published var names: [Named] = [] {
        didSet {
            searchIndex = names.sorted { $0.name < $1.name }.map { ($0, normalized($0.name)) }
            updateMatches()
        }
    }
    private var searchIndex: [(Named, String)] = []
    @Published private(set) var matches: [Named] = []
    @Published var pokemon: Pokemon?
    @Published private(set) var artworkImage: UIImage?
    @Published private(set) var artworkFailed = false
    private var artworkTask: Task<Void, Never>?
    private let artworkMemory = NSCache<NSURL, UIImage>()
    @Published var entryText = "Loading DexDuo entry…"
    @Published var entryVersion = ""
    @Published private(set) var spokenEntry: SpokenEntry?
    let selectionBegan = PassthroughSubject<Void, Never>()
    @Published var query = "" { didSet { updateMatches() } }
    @Published var loading = false
    @Published var error: String?
    private var requestID = UUID()
    private let api: any DexFetching
    init(api: any DexFetching = DexAPI.shared) { self.api = api }
    private func updateMatches() {
        let q = normalized(query)
        guard !q.isEmpty else { matches = []; return }
        // Normalize once when loading the index, not thousands of times on
        // the main thread during every keystroke and every view evaluation.
        let prefixes = searchIndex.lazy.filter { $0.1.hasPrefix(q) }.prefix(8).map { $0.0 }
        let remaining = 8 - prefixes.count
        let contains = searchIndex.lazy.filter { !$0.1.hasPrefix(q) && $0.1.contains(q) }.prefix(remaining).map { $0.0 }
        matches = Array(prefixes) + Array(contains)
    }
    func start() async {
        do { names = try await api.get("pokemon?limit=100000", as: IndexResponse.self).results }
        catch { self.error = "Couldn’t load the Pokémon index. Check your connection and retry." }
        await select("pikachu", automaticallyRead: false)
    }
    @discardableResult func select(_ name: String, reportError: Bool = true, automaticallyRead: Bool = true) async -> Bool {
        selectionBegan.send()
        let token = UUID(); requestID = token; loading = true; error = nil
        defer { if requestID == token { loading = false } }
        do {
            let value = try await api.get("pokemon/\(name)", as: Pokemon.self)
            guard requestID == token, !Task.isCancelled else { return false }
            var text = "DexDuo entry unavailable. Select this Pokémon again to retry."
            var version = ""
            var readyEntry: String?
            do {
                let species = try await api.get("pokemon-species/\(value.species.name)", as: Species.self)
                guard requestID == token, !Task.isCancelled else { return false }
                text = species.englishEntry?.cleanedText ?? "No English DexDuo entry is available."
                version = species.englishEntry?.version.title ?? ""
                readyEntry = species.englishEntry?.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                guard requestID == token, !Task.isCancelled else { return false }
            }
            // Publish the entry together. Cancellation during the species fetch
            // must leave the previous Pokémon and description intact.
            pokemon = value
            entryText = text
            entryVersion = version
            spokenEntry = readyEntry.flatMap { $0.isEmpty ? nil : SpokenEntry(id: token, name: value.title, text: $0, automaticallyRead: automaticallyRead) }
            loadArtwork(value.artwork, token: token)
            return true
        } catch {
            guard requestID == token, !Task.isCancelled else { return false }
            if reportError { self.error = "Couldn’t load this entry. Check your connection and try again." }
            return false
        }
    }
    private func loadArtwork(_ url: URL?, token: UUID) {
        artworkTask?.cancel()
        artworkFailed = false
        guard let url else { artworkImage = nil; artworkFailed = true; return }
        if let cached = artworkMemory.object(forKey: url as NSURL) {
            artworkImage = cached
            return
        }
        artworkImage = nil
        artworkTask = Task {
            do {
                let data = try await ArtworkDiskCache.shared.data(for: url)
                try Task.checkCancellation()
                guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                let decoded = await image.byPreparingForDisplay() ?? image
                try Task.checkCancellation()
                artworkMemory.setObject(decoded, forKey: url as NSURL, cost: data.count)
                guard requestID == token else { return }
                artworkImage = decoded
            } catch {
                if !Task.isCancelled && requestID == token { artworkFailed = true }
            }
        }
    }
    func step(_ direction: Int) async {
        guard let id = pokemon?.id else { return }
        let target = id + direction
        guard target > 0, names.contains(where: { $0.url.split(separator: "/").last.map(String.init) == String(target) }) else { return }
        await select(String(target))
    }
}

/// Persistent artwork bytes. The selected decoded UIImage is retained by
/// DexStore across fold/unfold; NSCache also speeds up revisiting entries.
actor ArtworkDiskCache {
    static let shared = ArtworkDiskCache()
    private let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DexDuoArtwork")
    private init() {}
    func data(for url: URL) async throws -> Data {
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key)
        if let bytes = try? Data(contentsOf: file), UIImage(data: bytes) != nil { return bytes }
        let (bytes, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200, UIImage(data: bytes) != nil else {
            throw URLError(.cannotDecodeContentData)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? bytes.write(to: file, options: .atomic)
        return bytes
    }
}
