import Foundation
import Combine

@MainActor
public final class CurrencyStore: ObservableObject {
    @Published public private(set) var selected: CurrencyCode = "USD"
    private let manager: CurrencyManager

    public init(manager: CurrencyManager = .shared) {
        self.manager = manager
        Task { await observe() }
    }

    public func set(_ code: CurrencyCode) async {
        await manager.setCurrency(code)
    }

    private func observe() async {
        for await value in await manager.$selectedCurrency.values {
            self.selected = value
        }
    }
}
