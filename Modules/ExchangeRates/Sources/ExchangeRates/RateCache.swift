import Foundation

public actor RateCache {
    private var payload: RatesResponse?
    private let url: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ExchangeRates/rates.json")

    public func load() -> RatesResponse? {
        payload ?? readFromDisk()
    }

    public func save(_ response: RatesResponse) async throws {
        payload = response
        try writeToDisk(response)
    }

    private func readFromDisk() -> RatesResponse? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RatesResponse.self, from: data)
    }

    private func writeToDisk(_ response: RatesResponse) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(response)
        try data.write(to: url)
    }
}
