import Foundation

public actor ExchangeRateManager {
    private let fetcher: any RateFetching
    private let cache: any RateCaching

    public init(
        fetcher: any RateFetching = RateFetcher(),
        cache: any RateCaching = RateCache()
    ) {
        self.fetcher = fetcher
        self.cache = cache
    }

    public func latest(base: CurrencyCode) async throws -> RatesResponse {
        if let cached = await cache.load(), !cached.isExpired {
            return cached
        }
        let fresh = try await fetcher.fetchLatest(base: base)
        try await cache.save(fresh)
        return fresh
    }
}

