import StoreKit
import SwiftUI

struct TipOffer: Identifiable, Sendable, Equatable {
    let id: String
    let price: String
}
struct TipReceipt: Sendable {
    let id: UInt64
    let productID: String
    let verified: Bool
}
enum TipPurchaseOutcome: Sendable { case cancelled, pending, completed(TipReceipt) }
protocol TipPurchasing: Sendable {
    func offers() async throws -> [TipOffer]
    func purchase(_ id: String) async throws -> TipPurchaseOutcome
    func unfinished() async -> [TipReceipt]
    func updates() async -> AsyncStream<TipReceipt>
    func finish(_ receipt: TipReceipt) async
}

actor AppleTips: TipPurchasing {
    private var products: [String: Product] = [:]
    private var transactions: [UInt64: StoreKit.Transaction] = [:]
    func offers() async throws -> [TipOffer] {
        let loaded = try await Product.products(for: TipStore.productIDs)
        products = Dictionary(uniqueKeysWithValues: loaded.filter { $0.type == .consumable }.map { ($0.id, $0) })
        return TipStore.productIDs.compactMap { id in products[id].map { TipOffer(id: id, price: $0.displayPrice) } }
    }
    func purchase(_ id: String) async throws -> TipPurchaseOutcome {
        guard let product = products[id] else { throw URLError(.resourceUnavailable) }
        switch try await product.purchase() {
        case .userCancelled: return .cancelled
        case .pending: return .pending
        case .success(let result): return .completed(receipt(result))
        @unknown default: throw URLError(.unknown)
        }
    }
    private func receipt(_ result: VerificationResult<StoreKit.Transaction>) -> TipReceipt {
        let transaction: StoreKit.Transaction
        let verified: Bool
        switch result {
        case .verified(let value): transaction = value; verified = value.revocationDate == nil && value.productType == .consumable
        case .unverified(let value, _): transaction = value; verified = false
        }
        if verified { transactions[transaction.id] = transaction }
        return TipReceipt(id: transaction.id, productID: transaction.productID, verified: verified)
    }
    func unfinished() async -> [TipReceipt] {
        var values: [TipReceipt] = []
        for await result in StoreKit.Transaction.unfinished { values.append(receipt(result)) }
        return values
    }
    func updates() async -> AsyncStream<TipReceipt> {
        AsyncStream { continuation in
            let task = Task {
                for await result in StoreKit.Transaction.updates {
                    guard !Task.isCancelled else { break }
                    continuation.yield(self.receipt(result))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
    func finish(_ receipt: TipReceipt) async {
        guard let transaction = transactions.removeValue(forKey: receipt.id) else { return }
        await transaction.finish()
    }
}

/// Calendar dates, rather than elapsed 24-hour intervals, handle daylight saving changes.
@MainActor final class TipPromptPolicy {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var eligibleDay: String?
    init(defaults: UserDefaults, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults; self.calendar = calendar; self.now = now
    }
    var supported: Bool { defaults.bool(forKey: "DexDuoSupported") }
    func recordSupport() { defaults.set(true, forKey: "DexDuoSupported"); eligibleDay = nil }
    private var day: String {
        let date = calendar.dateComponents([.era, .year, .month, .day], from: now())
        return "\(date.era ?? 0)-\(date.year ?? 0)-\(date.month ?? 0)-\(date.day ?? 0)"
    }
    func foreground() {
        let today = day
        eligibleDay = defaults.string(forKey: "DexDuoTipSessionDay") == today ? nil : today
        defaults.set(today, forKey: "DexDuoTipSessionDay")
    }
    func attempt(open: Bool, available: Bool, busy: Bool) -> Bool {
        guard open, let eligibleDay, eligibleDay == day, defaults.string(forKey: "DexDuoTipAttemptDay") != day, !supported else { return false }
        self.eligibleDay = nil
        defaults.set(eligibleDay, forKey: "DexDuoTipAttemptDay")
        return available && !busy
    }
}

@MainActor final class TipStore: ObservableObject {
    nonisolated static let productIDs = ["small", "medium", "large"].map { "com.harshulkuhar.dexduo.tip.\($0)" }
    @Published private(set) var offers: [TipOffer] = []
    @Published private(set) var purchasing = false
    @Published private(set) var message: String?
    @Published var presented = false
    var searchActive = false
    var settingsActive = false
    private let driver: any TipPurchasing
    private let policy: TipPromptPolicy
    private var listener: Task<Void, Never>?
    private var handled = Set<UInt64>()
    private var started = false
    private var foregroundActive = false
    var available: Bool { Set(offers.map(\.id)) == Set(Self.productIDs) }
    init(driver: any TipPurchasing = AppleTips(), defaults: UserDefaults = .standard,
         calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.driver = driver; policy = TipPromptPolicy(defaults: defaults, calendar: calendar, now: now)
    }
    deinit { listener?.cancel() }
    func start() async {
        guard !started else { return }; started = true
        let updates = await driver.updates()
        listener = Task { [weak self] in
            for await receipt in updates { guard let self, !Task.isCancelled else { break }; await self.accept(receipt) }
        }
        for receipt in await driver.unfinished() { await accept(receipt) }
        await reload()
    }
    func reload() async {
        do { offers = try await driver.offers(); message = available ? nil : "Tips are currently unavailable. Please try again later." }
        catch { offers = []; message = "Couldn’t load tips. Check your connection and try again." }
    }
    func foreground() {
        guard !foregroundActive else { return }; foregroundActive = true; policy.foreground()
    }
    func background() { foregroundActive = false }
    func consider(open: Bool, busy: Bool) {
        if policy.attempt(open: open, available: available, busy: busy || searchActive || settingsActive || presented) { presented = true }
    }
    func showManual() { message = nil; presented = true; if !available { Task { await reload() } } }
    func buy(_ id: String) async {
        guard !purchasing, available, Self.productIDs.contains(id) else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do {
            switch try await driver.purchase(id) {
            case .cancelled: break
            case .pending: message = "Awaiting approval. No completed tip has been recorded."
            case .completed(let receipt): await accept(receipt)
            }
        } catch { message = "The tip couldn’t be completed. Please try again." }
    }
    private func accept(_ receipt: TipReceipt) async {
        guard receipt.verified, Self.productIDs.contains(receipt.productID) else {
            message = "Apple’s purchase verification failed. No successful tip was recorded."; return
        }
        guard handled.insert(receipt.id).inserted else { return }
        // Persist before finishing so an interrupted launch cannot lose donor suppression.
        policy.recordSupport()
        message = "Thank you for supporting DexDuo!"
        await driver.finish(receipt)
    }
}

private struct TipStoreKey: EnvironmentKey { static let defaultValue: TipStore? = nil }
extension EnvironmentValues {
    var tipStore: TipStore? { get { self[TipStoreKey.self] } set { self[TipStoreKey.self] = newValue } }
}

struct TipPanel: View {
    @ObservedObject var store: TipStore
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    var body: some View {
        VStack(spacing: 12) {
            Text("Support DexDuo").font(.headline).accessibilityAddTraits(.isHeader)
            ScrollView {
                VStack(spacing: 12) {
                    Text("Leave an optional tip to support development. Tips unlock nothing and are not subscriptions.")
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(store.offers) { offer in
                        Button { Task { await store.buy(offer.id) } } label: {
                            Text("Leave a tip · \(offer.price)").frame(maxWidth: .infinity, minHeight: 44)
                        }.disabled(store.purchasing).accessibilityIdentifier(offer.id)
                    }
                    if !store.available { Button("Retry loading tips") { Task { await store.reload() } }.frame(minHeight: 44) }
                    if store.purchasing { ProgressView("Contacting Apple…") }
                    if let message = store.message { Text(message).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("tipStatus") }
                }
            }.scrollIndicators(.visible)
            Button("Not now") { store.presented = false }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("tipDismiss")
        }.font(.system(size: fontSize)).padding(16).frame(maxWidth: 420, maxHeight: 340)
            .background(DexAppearance.bezel, in: RoundedRectangle(cornerRadius: 12))
            .padding(12).accessibilityElement(children: .contain).accessibilityIdentifier("tipPanel").accessibilityAddTraits(.isModal)
    }
}
