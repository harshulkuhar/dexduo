import XCTest
import StoreKitTest
@testable import DexDuo

private actor FakeTips: TipPurchasing {
    var result = TipPurchaseOutcome.cancelled
    var loaded = TipStore.productIDs.map { TipOffer(id: $0, price: "$1") }
    var finished: [UInt64] = []
    var purchases = 0
    var fail = false
    var pendingReceipts: [TipReceipt] = []
    func set(_ value: TipPurchaseOutcome) { result = value }
    func unavailable() { loaded = [] }
    func setFailure() { fail = true }
    func setUnfinished(_ values: [TipReceipt]) { pendingReceipts = values }
    func offers() throws -> [TipOffer] { if fail { throw URLError(.notConnectedToInternet) }; return loaded }
    func purchase(_ id: String) async throws -> TipPurchaseOutcome {
        purchases += 1
        try await Task.sleep(for: .milliseconds(50))
        if fail { throw URLError(.notConnectedToInternet) }
        return result
    }
    func unfinished() -> [TipReceipt] { pendingReceipts }
    func updates() -> AsyncStream<TipReceipt> { AsyncStream { $0.finish() } }
    func finish(_ receipt: TipReceipt) { finished.append(receipt.id) }
}

@MainActor final class TipTests: XCTestCase {
    private func preferences() -> UserDefaults { UserDefaults(suiteName: "TipTests-\(UUID())")! }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testFirstForegroundDailyAttemptAndDST() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var now = date("2026-03-08T04:30:00Z") // March 7, before DST jump
        let defaults = preferences()
        let policy = TipPromptPolicy(defaults: defaults, calendar: calendar, now: { now })
        policy.foreground()
        XCTAssertFalse(policy.attempt(open: false, available: true, busy: false))
        XCTAssertTrue(policy.attempt(open: true, available: true, busy: false))
        XCTAssertFalse(policy.attempt(open: true, available: true, busy: false))
        let relaunched = TipPromptPolicy(defaults: defaults, calendar: calendar, now: { now })
        relaunched.foreground(); XCTAssertFalse(relaunched.attempt(open: true, available: true, busy: false))
        now = date("2026-03-08T08:00:00Z")
        XCTAssertFalse(policy.attempt(open: true, available: true, busy: false), "No midnight interruption")
        policy.foreground(); XCTAssertTrue(policy.attempt(open: true, available: true, busy: false))
    }
    func testSkippedDayDoesNotRetryAndSupportPersists() {
        for busy in [false, true] {
            let defaults = preferences(); let policy = TipPromptPolicy(defaults: defaults)
            policy.foreground()
            XCTAssertFalse(policy.attempt(open: true, available: busy, busy: busy))
            XCTAssertFalse(policy.attempt(open: true, available: true, busy: false))
            policy.recordSupport()
            XCTAssertTrue(TipPromptPolicy(defaults: defaults).supported)
        }
    }
    func testCancellationPendingFailureAndUnverifiedDoNotSuppress() async {
        let driver = FakeTips(); let defaults = preferences(); let store = TipStore(driver: driver, defaults: defaults)
        await store.start()
        for result in [TipPurchaseOutcome.cancelled, .pending, .completed(TipReceipt(id: 1, productID: TipStore.productIDs[0], verified: false))] {
            await driver.set(result); await store.buy(TipStore.productIDs[0]); XCTAssertFalse(defaults.bool(forKey: "DexDuoSupported"))
        }
        await driver.setFailure(); await store.buy(TipStore.productIDs[0]); XCTAssertFalse(defaults.bool(forKey: "DexDuoSupported"))
        XCTAssertNotNil(store.message)
    }
    func testVerifiedUnfinishedDuplicateAndConcurrentPurchase() async {
        let driver = FakeTips(); let defaults = preferences()
        let receipt = TipReceipt(id: 42, productID: TipStore.productIDs[0], verified: true)
        await driver.setUnfinished([receipt, receipt])
        let store = TipStore(driver: driver, defaults: defaults); await store.start()
        XCTAssertTrue(defaults.bool(forKey: "DexDuoSupported"))
        let finished = await driver.finished; XCTAssertEqual(finished, [42])
        await driver.set(.completed(receipt))
        async let first: () = store.buy(receipt.productID)
        async let second: () = store.buy(receipt.productID)
        _ = await (first, second)
        let count = await driver.purchases; XCTAssertEqual(count, 1)
        store.foreground(); store.consider(open: true, busy: false); XCTAssertFalse(store.presented)
        store.showManual(); XCTAssertTrue(store.presented, "Supporters retain manual tipping")
    }
    func testUnavailableAndBusySkipAutomaticPrompt() async {
        let driver = FakeTips(); await driver.unavailable()
        let store = TipStore(driver: driver, defaults: preferences()); store.foreground(); await store.start()
        store.consider(open: true, busy: false); XCTAssertFalse(store.presented)
        let ready = TipStore(driver: FakeTips(), defaults: preferences()); ready.foreground(); await ready.start()
        ready.searchActive = true; ready.consider(open: true, busy: false)
        ready.searchActive = false; ready.consider(open: true, busy: false); XCTAssertFalse(ready.presented)
    }
    func testNativeStoreKitConsumables() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalTips", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true; session.clearTransactions()
        defer { session.resetToDefaultState() }
        let driver = AppleTips(); var offers = try await driver.offers()
        for _ in 0..<10 where offers.isEmpty {
            try await Task.sleep(for: .milliseconds(100)); offers = try await driver.offers()
        }
        XCTAssertEqual(Set(offers.map(\.id)), Set(TipStore.productIDs))
        XCTAssertTrue(offers.allSatisfy { !$0.price.isEmpty })
        let defaults = preferences(); let store = TipStore(driver: driver, defaults: defaults)
        await store.start(); await store.buy(TipStore.productIDs[0])
        XCTAssertTrue(defaults.bool(forKey: "DexDuoSupported"))
        await store.buy(TipStore.productIDs[0]) // repeatable consumable
        XCTAssertFalse(store.purchasing)
    }
}
