import CalcCore
import Foundation
import HistoryStore
import UserNotifications
import os.log

// MARK: - Transaction Logger

@available(iOS 17.0, *)
public class TransactionLogger: ObservableObject {
    // MARK: - Singleton

    public static let shared = TransactionLogger()

    // MARK: - Properties

    private let historyStore = HistoryStore.shared
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    private init() {
        setupNotificationCategories()
    }

    // MARK: - Public Methods

    /// Handle incoming Apple Pay transaction from Shortcuts
    @MainActor
    public func handle(_ transaction: Transaction) async throws {
        // Get current wage from Keychain
        guard let wage = try HardenedKeychainManager.shared.loadWage() else {
            throw TransactionLoggerError.noWageConfigured
        }

        // Calculate work time
        let minutes = ConversionEngine.convertToWorkTime(
            price: transaction.amount,
            hourlyWage: wage.amount
        )

        // Create calculation record
        let calculation = Calculation(
            price: transaction.amount,
            currency: transaction.currency,
            minutes: minutes,
            source: .applePay,
            merchant: transaction.merchant,
            cardName: transaction.cardName,
            timestamp: Date()
        )

        // Save to history
        try await historyStore.save(calculation)

        // Post local notification
        await postNotification(for: calculation)
    }

    // MARK: - Notification Management

    private func setupNotificationCategories() {
        let undoAction = UNNotificationAction(
            identifier: "UNDO_TRANSACTION",
            title: "Undo",
            options: [.destructive]
        )

        let openAction = UNNotificationAction(
            identifier: "OPEN_TRANSACTION",
            title: "Open",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: "APPLE_PAY_MINUTES",
            actions: [undoAction, openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([category])
    }

    private func postNotification(for calculation: Calculation) async {
        let content = UNMutableNotificationContent()

        // Format notification text
        let formattedPrice = CurrencyUtilities.formatPrice(calculation.price, currency: calculation.currency)
        let formattedTime = ConversionEngine.formatWorkTime(calculation.minutes)
        let merchantName = calculation.merchant ?? "Purchase"

        content.title = "Apple Pay Transaction"
        content.body = "\(formattedPrice) \(merchantName) • \(formattedTime)"
        content.categoryIdentifier = "APPLE_PAY_MINUTES"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("SoftConfirm.caf"))

        // Add user info for deep linking
        content.userInfo = [
            "calculationId": calculation.id.uuidString,
            "source": "applePay",
        ]

        // Create request
        let request = UNNotificationRequest(
            identifier: "applePay_\(calculation.id.uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )

        // Post notification
        do {
            try await notificationCenter.add(request)
        } catch {
            #if DEBUG
                os_log(.error, "Failed to post notification: %{public}@", String(describing: error))
            #endif
        }
    }

    // MARK: - Notification Actions

    public func handleNotificationAction(_ actionIdentifier: String, calculationId: String) async {
        switch actionIdentifier {
        case "UNDO_TRANSACTION":
            await undoTransaction(calculationId: calculationId)
        case "OPEN_TRANSACTION":
            await openTransaction(calculationId: calculationId)
        default:
            break
        }
    }

    private func undoTransaction(calculationId: String) async {
        guard let uuid = UUID(uuidString: calculationId) else { return }

        do {
            try await historyStore.delete(calculationId: uuid)

            // Post confirmation notification
            let content = UNMutableNotificationContent()
            content.title = "Transaction Removed"
            content.body = "Apple Pay transaction has been removed from your history"
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(
                identifier: "undo_confirmation_\(calculationId)",
                content: content,
                trigger: nil
            )

            try await notificationCenter.add(request)
        } catch {
            #if DEBUG
                os_log(.error, "Failed to undo transaction: %{public}@", String(describing: error))
            #endif
        }
    }

    private func openTransaction(calculationId: String) async {
        // This will be handled by the app delegate to open the specific transaction
        NotificationCenter.default.post(
            name: .openTransactionDetail,
            object: nil,
            userInfo: ["calculationId": calculationId]
        )
    }
}

// MARK: - Transaction Model

@available(iOS 17.0, *)
public struct Transaction: Codable, Sendable {
    public let amount: Double
    public let currency: String
    public let merchant: String?
    public let cardName: String?
    public let timestamp: Date

    public init(
        amount: Double,
        currency: String,
        merchant: String? = nil,
        cardName: String? = nil,
        timestamp: Date = Date()
    ) {
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.cardName = cardName
        self.timestamp = timestamp
    }
}

// MARK: - Calculation Source Extension

public extension Calculation {
    enum Source: String, CaseIterable, Codable {
        case manual
        case ocr
        case applePay

        public var displayName: String {
            switch self {
            case .manual: return "Manual Entry"
            case .ocr: return "Receipt Scan"
            case .applePay: return "Apple Pay"
            }
        }

        public var icon: String {
            switch self {
            case .manual: return "keyboard"
            case .ocr: return "camera.viewfinder"
            case .applePay: return "applelogo"
            }
        }
    }
}

// MARK: - Errors

public enum TransactionLoggerError: LocalizedError {
    case noWageConfigured
    case invalidTransaction
    case notificationPermissionDenied

    public var errorDescription: String? {
        switch self {
        case .noWageConfigured:
            return "No wage configured. Please set up your hourly wage in LifeMeter first."
        case .invalidTransaction:
            return "Invalid transaction data received."
        case .notificationPermissionDenied:
            return "Notification permission required for Apple Pay automation."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTransactionDetail = Notification.Name("openTransactionDetail")
}
