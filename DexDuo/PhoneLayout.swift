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

enum DetailTab: String, CaseIterable {
    case info, stats, types, evolution
    var title: String { self == .evolution ? "EVO" : rawValue.uppercased() }
}
