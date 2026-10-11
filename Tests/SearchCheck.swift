import Foundation
@main struct SearchCheck {
    @MainActor static func main() {
        let store = DexStore()
        store.names = [Named(name: "pikachu", url: ""), Named(name: "pichu", url: ""), Named(name: "raichu", url: ""), Named(name: "mr-mime", url: "")]
        for query in ["p", "pi", "pik", "pika", "pikac", "pikachu"] {
            store.query = query
            precondition(store.matches.contains { $0.name == "pikachu" })
        }
        store.query = "Mr. Mime"
        precondition(store.matches.first?.name == "mr-mime")
        store.query = "zzzz"
        precondition(store.matches.isEmpty)
        store.query = ""
        precondition(store.matches.isEmpty)
        print("PASS: incremental typing, punctuation, no-match and clear")
    }
}
