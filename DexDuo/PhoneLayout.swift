import Foundation

enum DeviceProfile: Equatable {
    case unresolved, phone, duo, tablet
}

struct DeviceProfileState {
    private(set) var profile: DeviceProfile = .unresolved
    private(set) var isFolded = true

    mutating func observe(isPhone: Bool, hasHinge: Bool, closed: Bool?) {
        if hasHinge {
            profile = .duo
            if let closed { isFolded = closed }
        } else if profile != .duo {
            profile = isPhone ? .phone : .tablet
        }
    }
}

struct PhoneLayoutMetrics {
    static let margin: CGFloat = 12
    static let spacing: CGFloat = 8
    static let toolbarHeight: CGFloat = 44
    static let dividerWidth: CGFloat = 2

    let size: CGSize
    var contentWidth: CGFloat { max(0, size.width - Self.margin * 2) }
    var panelWidth: CGFloat { max(0, (contentWidth - Self.spacing * 2 - Self.dividerWidth) / 2) }

    static func visibleHeight(bounds: CGRect, keyboard: CGRect?) -> CGFloat {
        guard let keyboard, keyboard.intersects(bounds) else { return bounds.height }
        return max(0, min(bounds.height, keyboard.minY - bounds.minY))
    }

    static func resultCapacity(height: CGFloat, rowHeight: CGFloat = 44, maximum: Int = 3) -> Int {
        max(1, min(maximum, Int((max(0, height) + 4) / (rowHeight + 4))))
    }
}

enum PhoneDetailTab: String, CaseIterable {
    case info = "Info", stats = "Stats", types = "Types"
}

enum TextPages {
    /// Greedy word wrapping; oversized tokens split at grapheme boundaries without losing characters.
    static func paginate(_ text: String, fits: (String) -> Bool) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [""] }
        var pages: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            if fits(candidate) { current = candidate; continue }
            if !current.isEmpty { pages.append(current); current = "" }
            if fits(word) { current = word; continue }
            for character in word {
                let next = current + String(character)
                if !current.isEmpty && !fits(next) { pages.append(current); current = "" }
                current.append(character)
            }
        }
        if !current.isEmpty { pages.append(current) }
        return pages
    }
}
