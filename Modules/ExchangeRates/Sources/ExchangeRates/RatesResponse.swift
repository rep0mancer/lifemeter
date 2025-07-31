import Foundation

public struct RatesResponse: Codable {
    public let base: CurrencyCode
    public let date: Date
    public let rates: [CurrencyCode: Double]

    public var isExpired: Bool {
        guard let expiry = Calendar.current.date(byAdding: .day, value: 1, to: date) else {
            return true
        }
        return Date() >= expiry
    }
}

