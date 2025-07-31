import Combine
import Foundation

public protocol CurrencyManaging: Actor {
    var selectedCurrency: CurrencyCode { get }
    var selectedCurrencyPublisher: Published<CurrencyCode>.Publisher { get }
    func setCurrency(_ currencyCode: CurrencyCode)
}

extension CurrencyManager: CurrencyManaging {
    public var selectedCurrencyPublisher: Published<CurrencyCode>.Publisher { $selectedCurrency }
}

