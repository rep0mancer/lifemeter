import XCTest
@testable import ExchangeRates

@MainActor
final class RateManagerTests: XCTestCase {
    actor FakeFetcher: RateFetching {
        var payload: RatesResponse
        var fetchCount = 0
        init(payload: RatesResponse) { self.payload = payload }
        func fetchLatest(base: CurrencyCode) async throws -> RatesResponse {
            fetchCount += 1
            return payload
        }
    }

    actor FakeCache: RateCaching {
        var stored: RatesResponse?
        init(initial: RatesResponse? = nil) { stored = initial }
        func load() -> RatesResponse? { stored }
        func save(_ response: RatesResponse) async throws { stored = response }
    }

    func test_cached_path_hits_without_network() async throws {
        let today = Date()
        let cached = RatesResponse(base: "USD", date: today, rates: ["EUR": 0.9])
        let fetcher = FakeFetcher(payload: RatesResponse(base: "USD", date: today, rates: ["EUR": 1.1]))
        let cache = FakeCache(initial: cached)
        let manager = ExchangeRateManager(fetcher: fetcher, cache: cache)

        let result = try await manager.latest(base: "USD")

        XCTAssertEqual(result.rates["EUR"], 0.9)
        let fetchCount = await fetcher.fetchCount
        XCTAssertEqual(fetchCount, 0)
    }

    func test_fresh_path_when_expired() async throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let expired = RatesResponse(base: "USD", date: oldDate, rates: ["EUR": 0.8])
        let fresh = RatesResponse(base: "USD", date: Date(), rates: ["EUR": 0.9])
        let fetcher = FakeFetcher(payload: fresh)
        let cache = FakeCache(initial: expired)
        let manager = ExchangeRateManager(fetcher: fetcher, cache: cache)

        let result = try await manager.latest(base: "USD")

        XCTAssertEqual(result.rates["EUR"], 0.9)
        let fetchCount = await fetcher.fetchCount
        XCTAssertEqual(fetchCount, 1)
        let cached = await cache.load()
        XCTAssertEqual(cached?.date, fresh.date)
    }
}

