import Foundation

public actor ExchangeRateManager {
    private let fetcher = RateFetcher()
    private let cache = RateCache()

    public init() {}

    public func latest(base: CurrencyCode) async throws -> RatesResponse {
        if let cached = cache.load(), !cached.isExpired {
            return cached
        }
        let fresh = try await fetcher.fetchLatest(base: base)
        try await cache.save(fresh)
        return fresh
    }
}
