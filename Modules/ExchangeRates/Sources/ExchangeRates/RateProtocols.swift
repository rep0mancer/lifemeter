import Foundation

public protocol RateFetching: Sendable {
    func fetchLatest(base: CurrencyCode) async throws -> RatesResponse
}

public protocol RateCaching: Sendable {
    func load() -> RatesResponse?
    func save(_ response: RatesResponse) async throws
}

