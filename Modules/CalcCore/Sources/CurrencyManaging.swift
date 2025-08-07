import Combine
import Foundation

public protocol CurrencyManaging: Actor {
    var selectedCurrency: CurrencyCode { get }
    var selectedCurrencyStream: AsyncStream<CurrencyCode> { get }
    func setCurrency(_ currencyCode: CurrencyCode)
}

extension CurrencyManager: CurrencyManaging {}

