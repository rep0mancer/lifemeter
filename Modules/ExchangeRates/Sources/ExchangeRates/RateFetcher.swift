// swiftlint:disable force_unwrapping
import Foundation

public actor RateFetcher: RateFetching {
    private let session: URLSession = .shared

    public init() {}

    public func fetchLatest(base: CurrencyCode) async throws -> RatesResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.exchangerate.host"
        components.path = "/latest"
        components.queryItems = [
            URLQueryItem(name: "base", value: base),
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

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

