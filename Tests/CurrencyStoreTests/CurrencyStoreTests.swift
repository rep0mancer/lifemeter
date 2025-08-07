import Combine
import XCTest
@testable import CalcCore

@MainActor
final class CurrencyStoreTests: XCTestCase {
    actor InMemoryCurrencyManager: CurrencyManaging {
        var selectedCurrency: CurrencyCode = "USD"
        private var continuation: AsyncStream<CurrencyCode>.Continuation?
        var selectedCurrencyStream: AsyncStream<CurrencyCode> {
            AsyncStream { cont in
                continuation = cont
                cont.onTermination = { [weak self] _ in self?.continuation = nil }
                cont.yield(selectedCurrency)
            }
        }
        func setCurrency(_ currencyCode: CurrencyCode) {
            selectedCurrency = currencyCode
            continuation?.yield(currencyCode)
        }
    }

    func test_selected_updates_on_main_thread() async throws {
        let manager = InMemoryCurrencyManager()
        let store = CurrencyStore(manager: manager)
        let exp = expectation(description: "update")

        let cancellable = store.$selected.dropFirst().sink { value in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value, "GBP")
            exp.fulfill()
        }

        await store.set("GBP")
await fulfillment(of: [exp], timeout: 1)
        _ = cancellable
    }
}

