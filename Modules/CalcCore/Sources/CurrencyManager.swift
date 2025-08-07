import Combine
import Foundation

public typealias CurrencyCode = String

// MARK: - Currency Manager

public actor CurrencyManager {
    // MARK: - Singleton

    public static let shared = CurrencyManager()

    // MARK: - Properties

    private var selectedCurrencyValue: CurrencyCode = "EUR"
    private var continuations: [UUID: AsyncStream<CurrencyCode>.Continuation] = [:]

    // MARK: - Initialization

    private init() {
        loadSelectedCurrency()
    }

    // MARK: - Public Methods

    /// Current selected currency
    public var selectedCurrency: CurrencyCode { selectedCurrencyValue }

    /// Async stream for selected currency changes (supports multiple subscribers)
    public nonisolated var selectedCurrencyStream: AsyncStream<CurrencyCode> {
        let id = UUID()
        return AsyncStream { continuation in
            // Register inside actor and yield the current value immediately
            Task { await self.addContinuation(id: id, continuation: continuation) }
            // Ensure removal when this specific stream terminates
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    /// Validate and set currency code
    public func setCurrency(_ currencyCode: CurrencyCode) {
        guard CurrencyUtilities.supportedCurrencyCodes.contains(currencyCode) else { return }
        selectedCurrencyValue = currencyCode
        // Broadcast to all active subscribers
        for continuation in continuations.values {
            continuation.yield(currencyCode)
        }
        saveSelectedCurrency()
    }

    /// Get currency symbol for code
    public nonisolated func symbol(for currencyCode: String) -> String {
        guard CurrencyUtilities.supportedCurrencyCodes.contains(currencyCode) else {
            return currencyCode // Fallback to code if unsupported
        }

        return CurrencyUtilities.symbol(for: currencyCode)
    }

    /// Check if currency code is supported
    public nonisolated func isSupported(_ currencyCode: String?) -> Bool {
        guard let code = currencyCode else { return false }
        return CurrencyUtilities.supportedCurrencyCodes.contains(code)
    }

    /// Get all supported currency codes
    public nonisolated var supportedCurrencies: [String] {
        return Array(CurrencyUtilities.supportedCurrencyCodes).sorted()
    }

    /// Validate currency code before conversion
    public nonisolated func validateCurrencyForConversion(_ currencyCode: String?) throws {
        guard let code = currencyCode else {
            throw CurrencyError.invalidCurrencyCode("Currency code is required for conversion")
        }

        guard CurrencyUtilities.supportedCurrencyCodes.contains(code) else {
            throw CurrencyError.unsupportedCurrency("Unsupported currency. Please choose a different code.")
        }
    }

    // MARK: - Private Methods

    private func loadSelectedCurrency() {
        if let saved = UserDefaults.standard.string(forKey: "SelectedCurrency"),
           CurrencyUtilities.supportedCurrencyCodes.contains(saved)
        {
            selectedCurrencyValue = saved
        } else if let localeCode = getLocaleCurrency() {
            selectedCurrencyValue = localeCode
        }
    }

    private func saveSelectedCurrency() {
        UserDefaults.standard.set(selectedCurrencyValue, forKey: "SelectedCurrency")
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<CurrencyCode>.Continuation) {
        continuations[id] = continuation
        continuation.yield(selectedCurrencyValue)
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    /// Get currency from user's locale
    private func getLocaleCurrency() -> String? {
        guard let localeCode = Locale.current.currencyCode,
              CurrencyUtilities.supportedCurrencyCodes.contains(localeCode)
        else {
            return nil
        }
        return localeCode
    }
}

// MARK: - Currency Error

public enum CurrencyError: LocalizedError {
    case invalidCurrencyCode(String)
    case unsupportedCurrency(String)
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidCurrencyCode(message):
            return message
        case let .unsupportedCurrency(message):
            return message
        case let .conversionFailed(message):
            return message
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidCurrencyCode:
            return "Please provide a valid currency code."
        case .unsupportedCurrency:
            return "Please choose from: EUR, USD, GBP, JPY, CHF, CAD, AUD."
        case .conversionFailed:
            return "Please try again or contact support."
        }
    }
}

// MARK: - Enhanced Conversion Engine

public extension ConversionEngine {
    /// Convert price to work time with currency validation
    static func convertToWorkTimeWithValidation(
        price: Double,
        currency: String,
        hourlyWage: Double
    ) throws -> Double {
        // Validate currency
        try CurrencyManager.shared.validateCurrencyForConversion(currency)

        // Validate inputs
        guard price >= 0 else {
            throw CurrencyError.conversionFailed("Price cannot be negative")
        }

        guard hourlyWage > 0 else {
            throw CurrencyError.conversionFailed("Hourly wage must be greater than zero")
        }

        // Perform conversion
        return convertToWorkTime(price: price, hourlyWage: hourlyWage)
    }

    /// Format price with currency validation
    static func formatPriceWithValidation(
        _ price: Double,
        currency: String
    ) throws -> String {
        // Validate currency
        try CurrencyManager.shared.validateCurrencyForConversion(currency)

        // Format price
        return CurrencyUtilities.formatPrice(price, currency: currency)
    }
}

// MARK: - Currency Utilities Extension

public extension CurrencyUtilities {
    /// Get currency symbol with fallback
    static func safeSymbol(for currencyCode: String) -> String {
        let supportedCurrencies = CurrencyManager.shared.supportedCurrencies

        guard supportedCurrencies.contains(currencyCode) else {
            return currencyCode // Return code as fallback
        }

        return symbol(for: currencyCode)
    }

    /// Validate currency code
    static func isValidCurrency(_ currencyCode: String?) -> Bool {
        return CurrencyManager.shared.isSupported(currencyCode)
    }

    /// Get currency info
    static func getCurrencyInfo(for code: String) -> (symbol: String, name: String)? {
        guard CurrencyManager.shared.isSupported(code) else { return nil }

        let currencyNames: [String: String] = [
            "EUR": "Euro",
            "USD": "US Dollar",
            "GBP": "British Pound",
            "JPY": "Japanese Yen",
            "CHF": "Swiss Franc",
            "CAD": "Canadian Dollar",
            "AUD": "Australian Dollar",
        ]

        return (
            symbol: symbol(for: code),
            name: currencyNames[code] ?? code
        )
    }
}

// MARK: - Currency Validation Helper

public struct CurrencyValidator {
    /// Validate currency code with detailed error
    public static func validate(_ currencyCode: String?) -> ValidationResult {
        guard let code = currencyCode, !code.isEmpty else {
            return .invalid("Currency code cannot be empty")
        }

        guard code.count == 3 else {
            return .invalid("Currency code must be 3 characters")
        }

        guard code.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
            return .invalid("Currency code must contain only uppercase letters")
        }

        guard CurrencyManager.shared.isSupported(code) else {
            return .invalid("Currency '\(code)' is not supported")
        }

        return .valid
    }

    public enum ValidationResult {
        case valid
        case invalid(String)

        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        public var errorMessage: String? {
            if case let .invalid(message) = self { return message }
            return nil
        }
    }
}

// MARK: - Currency Selection Helper

public struct CurrencySelection {
    public let code: String
    public let symbol: String
    public let name: String
    public let isSupported: Bool

    public init(code: String) {
        self.code = code
        isSupported = CurrencyManager.shared.isSupported(code)

        if isSupported, let info = CurrencyUtilities.getCurrencyInfo(for: code) {
            symbol = info.symbol
            name = info.name
        } else {
            symbol = code
            name = "Unknown Currency"
        }
    }

    public static func allSupported() -> [CurrencySelection] {
        return CurrencyManager.shared.supportedCurrencies.map { CurrencySelection(code: $0) }
    }
}
