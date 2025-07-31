import Combine
import Foundation

@MainActor
public final class CurrencyStore: ObservableObject {
    @Published public private(set) var selected: CurrencyCode = "USD"
    private let manager: any CurrencyManaging

    public init(manager: any CurrencyManaging = CurrencyManager.shared) {
        self.manager = manager
        Task { await observe() }
    }

    public func set(_ code: CurrencyCode) async {
        await manager.setCurrency(code)
    }

    private func observe() async {
        for await value in await manager.selectedCurrencyPublisher.values {
            selected = value
        }
    }
}

