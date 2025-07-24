import Foundation
import Security

// MARK: - Keychain Manager
///
/// This `KeychainManager` provides a simple API for storing and retrieving a user's wage and
/// currency preferences.  It wraps the system Keychain APIs for persistence and
/// interoperability with existing data stored in earlier versions of the app.
///
/// Additionally, it exposes methods for saving and deleting full ``Wage`` values by
/// delegating to ``HardenedKeychainManager``.  These methods bridge the older
/// double‑and‑string based storage to the more secure ``WageData`` format used by
/// integration and transaction logging tests.
public class KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.lifemeter.app"
    private let wageKey = "user_hourly_wage"
    private let currencyKey = "user_currency"
    
    private init() {}
    
    // MARK: - Wage Management
    
    /// Stores the user's hourly wage securely in Keychain.
    ///
    /// This method persists only the numeric wage amount for backwards
    /// compatibility.  To save a full ``Wage`` including period, use
    /// ``saveWage(_:)`` instead.
    /// - Parameter wage: Hourly wage to store
    /// - Returns: Success status
    @discardableResult
    public func storeWage(_ wage: Double) -> Bool {
        let data = Data(String(wage).utf8)
        return storeData(data, for: wageKey)
    }
    
    /// Retrieves the user's hourly wage from Keychain.
    /// - Returns: Hourly wage or nil if not found
    public func retrieveWage() -> Double? {
        guard let data = retrieveData(for: wageKey),
              let wageString = String(data: data, encoding: .utf8),
              let wage = Double(wageString) else {
            return nil
        }
        return wage
    }
    
    /// Stores the user's preferred currency.
    /// - Parameter currency: Currency code to store
    /// - Returns: Success status
    @discardableResult
    public func storeCurrency(_ currency: String) -> Bool {
        let data = Data(currency.utf8)
        return storeData(data, for: currencyKey)
    }
    
    /// Retrieves the user's preferred currency.
    /// - Returns: Currency code or system default
    public func retrieveCurrency() -> String {
        guard let data = retrieveData(for: currencyKey),
              let currency = String(data: data, encoding: .utf8) else {
            return Locale.current.currency?.identifier ?? "EUR"
        }
        return currency
    }
    
    /// Removes wage data from Keychain.
    /// - Returns: Success status
    @discardableResult
    public func removeWage() -> Bool {
        return removeData(for: wageKey)
    }
    
    /// Removes currency data from Keychain.
    /// - Returns: Success status
    @discardableResult
    public func removeCurrency() -> Bool {
        return removeData(for: currencyKey)
    }
    
    /// Checks if wage is stored.
    /// - Returns: True if wage exists in Keychain
    public func hasWage() -> Bool {
        return retrieveWage() != nil
    }
    
    // MARK: - WageData bridging
    
    /// Saves a complete ``Wage`` using the hardened keychain.
    ///
    /// This convenience method constructs a ``WageData`` from the provided wage
    /// information and delegates to ``HardenedKeychainManager`` to persist the
    /// data securely.  It also stores the wage amount and currency in the
    /// legacy keychain keys to maintain backwards compatibility with parts of
    /// the app that still rely on the older storage.
    ///
    /// - Parameter wage: The `Wage` to save.
    /// - Throws: Rethrows any error thrown by ``HardenedKeychainManager.saveWage(_:)``.
    public func saveWage(_ wage: Wage) throws {
        let wageData = WageData(amount: wage.amount, currency: wage.currency, period: wage.period)
        try HardenedKeychainManager.shared.saveWage(wageData)
        // Also store legacy values for backwards compatibility
        _ = storeWage(wage.amount)
        _ = storeCurrency(wage.currency)
    }
    
    /// Deletes wage information from both the hardened keychain and the legacy keys.
    ///
    /// - Throws: Rethrows any error thrown by ``HardenedKeychainManager.deleteWage()``.
    public func deleteWage() throws {
        try HardenedKeychainManager.shared.deleteWage()
        // Remove legacy keys
        _ = removeWage()
        _ = removeCurrency()
    }
    
    // MARK: - Private Keychain Operations
    
    private func storeData(_ data: Data, for key: String) -> Bool {
        // Delete existing item first
        removeData(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func retrieveData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private func removeData(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Keychain Errors
public enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .invalidData:
            return "Invalid data format"
        case .unexpectedStatus(let status):
            return "Unexpected Keychain status: \(status)"
        }
    }
}
