import Foundation

// MARK: - Currency Manager
public class CurrencyManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = CurrencyManager()
    
    // MARK: - Properties
    @Published public var selectedCurrency: String = "EUR"
    
    private let supportedCurrencyCodes: Set<String> = [
        "EUR", "USD", "GBP", "JPY", "CHF", "CAD", "AUD"
    ]
    
    // MARK: - Initialization
    private init() {
        loadSelectedCurrency()
    }
    
    // MARK: - Public Methods
    
    /// Validate and set currency code
    public func setCurrency(_ currencyCode: String?) throws {
        guard let code = currencyCode, !code.isEmpty else {
            throw CurrencyError.invalidCurrencyCode("Currency code cannot be nil or empty")
        }
        
        guard supportedCurrencyCodes.contains(code) else {
            throw CurrencyError.unsupportedCurrency("Unsupported currency: \(code). Please choose a different code.")
        }
        
        selectedCurrency = code
        saveSelectedCurrency()
    }
    
    /// Get currency symbol for code
    public func symbol(for currencyCode: String) -> String {
        guard supportedCurrencyCodes.contains(currencyCode) else {
            return currencyCode // Fallback to code if unsupported
        }
        
        return CurrencyUtilities.symbol(for: currencyCode)
    }
    
    /// Check if currency code is supported
    public func isSupported(_ currencyCode: String?) -> Bool {
        guard let code = currencyCode else { return false }
        return supportedCurrencyCodes.contains(code)
    }
    
    /// Get all supported currency codes
    public var supportedCurrencies: [String] {
        return Array(supportedCurrencyCodes).sorted()
    }
    
    /// Validate currency code before conversion
    public func validateCurrencyForConversion(_ currencyCode: String?) throws {
        guard let code = currencyCode else {
            throw CurrencyError.invalidCurrencyCode("Currency code is required for conversion")
        }
        
        guard supportedCurrencyCodes.contains(code) else {
            throw CurrencyError.unsupportedCurrency("Unsupported currency. Please choose a different code.")
        }
    }
    
    /// Get currency from user's locale
    public func getLocaleCurrency() -> String? {
        guard let localeCode = Locale.current.currencyCode,
              supportedCurrencyCodes.contains(localeCode) else {
            return nil
        }
        return localeCode
    }
    
    // MARK: - Private Methods
    
    private func loadSelectedCurrency() {
        if let saved = UserDefaults.standard.string(forKey: "SelectedCurrency"),
           supportedCurrencyCodes.contains(saved) {
            selectedCurrency = saved
        } else if let localeCode = getLocaleCurrency() {
            selectedCurrency = localeCode
        }
    }
    
    private func saveSelectedCurrency() {
        UserDefaults.standard.set(selectedCurrency, forKey: "SelectedCurrency")
    }
}

// MARK: - Currency Error
public enum CurrencyError: LocalizedError {
    case invalidCurrencyCode(String)
    case unsupportedCurrency(String)
    case conversionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCurrencyCode(let message):
            return message
        case .unsupportedCurrency(let message):
            return message
        case .conversionFailed(let message):
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
extension ConversionEngine {
    
    /// Convert price to work time with currency validation
    public static func convertToWorkTimeWithValidation(
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
    public static func formatPriceWithValidation(
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
extension CurrencyUtilities {
    
    /// Get currency symbol with fallback
    public static func safeSymbol(for currencyCode: String) -> String {
        let supportedCurrencies = CurrencyManager.shared.supportedCurrencies
        
        guard supportedCurrencies.contains(currencyCode) else {
            return currencyCode // Return code as fallback
        }
        
        return symbol(for: currencyCode)
    }
    
    /// Validate currency code
    public static func isValidCurrency(_ currencyCode: String?) -> Bool {
        return CurrencyManager.shared.isSupported(currencyCode)
    }
    
    /// Get currency info
    public static func getCurrencyInfo(for code: String) -> (symbol: String, name: String)? {
        guard CurrencyManager.shared.isSupported(code) else { return nil }
        
        let currencyNames: [String: String] = [
            "EUR": "Euro",
            "USD": "US Dollar",
            "GBP": "British Pound",
            "JPY": "Japanese Yen",
            "CHF": "Swiss Franc",
            "CAD": "Canadian Dollar",
            "AUD": "Australian Dollar"
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
            if case .invalid(let message) = self { return message }
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
        self.isSupported = CurrencyManager.shared.isSupported(code)
        
        if isSupported, let info = CurrencyUtilities.getCurrencyInfo(for: code) {
            self.symbol = info.symbol
            self.name = info.name
        } else {
            self.symbol = code
            self.name = "Unknown Currency"
        }
    }
    
    public static func allSupported() -> [CurrencySelection] {
        return CurrencyManager.shared.supportedCurrencies.map { CurrencySelection(code: $0) }
    }
}

