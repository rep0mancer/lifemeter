import AppIntents
import Foundation
import HistoryStore

// MARK: - Log Transaction Intent

@available(iOS 17.0, *)
public struct LogTransactionIntent: AppIntent {
    // MARK: - Intent Configuration

    public static var title: LocalizedStringResource = "Log Apple Pay Transaction"
    public static var description = IntentDescription("Automatically log Apple Pay transactions to LifeMeter")
    public static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Transaction Amount")
    public var amount: Double

    @Parameter(title: "Currency Code")
    public var currency: String

    @Parameter(title: "Merchant Name")
    public var merchant: String?

    @Parameter(title: "Card Name")
    public var cardName: String?

    // MARK: - Initialization

    public init() {}

    public init(amount: Double, currency: String, merchant: String? = nil, cardName: String? = nil) {
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.cardName = cardName
    }

    // MARK: - Intent Execution

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Validate input
        guard amount > 0 else {
            throw LogTransactionError.invalidAmount
        }

        guard !currency.isEmpty else {
            throw LogTransactionError.invalidCurrency
        }

        // Create transaction object
        let transaction = Transaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            cardName: cardName,
            timestamp: Date()
        )

        // Process transaction
        do {
            try await TransactionLogger.shared.handle(transaction)

            // Return success result with summary
            let formattedPrice = CurrencyUtilities.formatPrice(amount, currency: currency)
            let wage = try? HardenedKeychainManager.shared.loadWage()
            let minutes = ConversionEngine.convertToWorkTime(price: amount, hourlyWage: wage?.amount ?? 0)
            let formattedTime = ConversionEngine.formatWorkTime(minutes)

            return .result(
                value: "Logged \(formattedPrice) transaction (\(formattedTime) of work)",
                dialog: IntentDialog("Transaction logged: \(formattedPrice) equals \(formattedTime) of work")
            )

        } catch {
            throw LogTransactionError.processingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Transaction Entity

@available(iOS 17.0, *)
public struct TransactionEntity: AppEntity {
    public let id: UUID
    public let amount: Double
    public let currency: String
    public let merchant: String?
    public let cardName: String?
    public let timestamp: Date

    public var displayRepresentation: DisplayRepresentation {
        let formattedPrice = CurrencyUtilities.formatPrice(amount, currency: currency)
        let merchantName = merchant ?? "Unknown Merchant"
        return DisplayRepresentation(
            title: "\(formattedPrice) at \(merchantName)",
            subtitle: cardName ?? "Apple Pay"
        )
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Transaction"
    public static var defaultQuery = TransactionQuery()
}

// MARK: - Transaction Query

@available(iOS 17.0, *)
public struct TransactionQuery: EntityQuery {
    public func entities(for _: [UUID]) async throws -> [TransactionEntity] {
        // This would typically fetch from HistoryStore
        // For now, return empty as we're primarily handling incoming transactions
        return []
    }

    public func suggestedEntities() async throws -> [TransactionEntity] {
        // Return recent Apple Pay transactions for suggestions
        return []
    }
}

// MARK: - Shortcuts Provider

@available(iOS 17.0, *)
public struct LifeMeterShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTransactionIntent(),
            phrases: [
                "Log transaction in LifeMeter",
                "Add Apple Pay transaction to LifeMeter",
                "Calculate work time for purchase",
            ],
            shortTitle: "Log Transaction",
            systemImageName: "applelogo"
        )
    }
}

// MARK: - Intent Errors

public enum LogTransactionError: LocalizedError {
    case invalidAmount
    case invalidCurrency
    case processingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Transaction amount must be greater than zero"
        case .invalidCurrency:
            return "Invalid currency code provided"
        case let .processingFailed(message):
            return "Failed to process transaction: \(message)"
        }
    }
}

// MARK: - App Intent Configuration

@available(iOS 17.0, *)
public extension LogTransactionIntent {
    /// Create intent from Shortcuts transaction data
    static func from(shortcutsData: [String: Any]) -> LogTransactionIntent? {
        guard let amount = shortcutsData["amount"] as? Double,
              let currency = shortcutsData["currency"] as? String
        else {
            return nil
        }

        let merchant = shortcutsData["merchant"] as? String
        let cardName = shortcutsData["cardName"] as? String

        return LogTransactionIntent(
            amount: amount,
            currency: currency,
            merchant: merchant,
            cardName: cardName
        )
    }

    /// Convert to dictionary for Shortcuts export
    func toShortcutsData() -> [String: Any] {
        var data: [String: Any] = [
            "amount": amount,
            "currency": currency,
        ]

        if let merchant = merchant {
            data["merchant"] = merchant
        }

        if let cardName = cardName {
            data["cardName"] = cardName
        }

        return data
    }
}
