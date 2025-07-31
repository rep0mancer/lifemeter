// swiftlint:disable force_unwrapping
import Foundation

public actor RateFetcher: RateFetching {
    private let session: URLSession = .shared

    public init() {}

    public func fetchLatest(base: CurrencyCode) async throws -> RatesResponse {
        let url = URL(string: "https://api.exchangerate.host/latest?base=\(base)")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        return try decoder.decode(RatesResponse.self, from: data)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .init(secondsFromGMT: 0)
        return formatter
    }()
}

