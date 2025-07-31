// swiftlint:disable force_unwrapping
import Foundation
import LocalAuthentication
import Security
import os.log

// MARK: - Hardened Keychain Manager

public class HardenedKeychainManager {
    // MARK: - Singleton

    public static let shared = HardenedKeychainManager()

    // MARK: - Properties

    private let service = "com.lifemeter.secure-storage"
    private let accessGroup: String? = nil // Use nil for single-app access

    // MARK: - Security Configuration

    private let securityLevel: SecurityLevel
    private let biometricPolicy: BiometricPolicy

    // MARK: - Initialization

    private init(securityLevel: SecurityLevel = .high, biometricPolicy: BiometricPolicy = .optional) {
        self.securityLevel = securityLevel
        self.biometricPolicy = biometricPolicy
    }

    // MARK: - Public Methods

    /// Save wage data with enhanced security
    public func saveWage(_ wage: WageData) throws {
        let data = try JSONEncoder().encode(wage)
        let encryptedData = try encryptData(data)

        let query = createBaseQuery(for: .wage)
        let attributes = createSecureAttributes(for: encryptedData)

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item with enhanced security
        var finalQuery = query
        finalQuery.merge(attributes) { _, new in new }

        let status = SecItemAdd(finalQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }

        // Log security event
        logSecurityEvent(.wageStored, details: "Wage data encrypted and stored")
    }

    /// Load wage data with security validation
    public func loadWage() throws -> WageData? {
        let query = createLoadQuery(for: .wage)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let decryptedData = try decryptData(data)
        let wage = try JSONDecoder().decode(WageData.self, from: decryptedData)

        // Validate wage data integrity
        try validateWageData(wage)

        // Log security event
        logSecurityEvent(.wageAccessed, details: "Wage data decrypted and validated")

        return wage
    }

    /// Delete wage data securely
    public func deleteWage() throws {
        let query = createBaseQuery(for: .wage)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }

        // Log security event
        logSecurityEvent(.wageDeleted, details: "Wage data securely deleted")
    }

    /// Check if biometric authentication is available and configured
    public func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?

        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Validate Keychain integrity
    public func validateKeychainIntegrity() throws -> KeychainIntegrityReport {
        var report = KeychainIntegrityReport()

        // Check if wage data exists
        do {
            let wage = try loadWage()
            report.wageDataExists = wage != nil

            if let wage = wage {
                try validateWageData(wage)
                report.wageDataValid = true
            }
        } catch {
            report.wageDataValid = false
            report.errors.append("Wage data validation failed: \(error.localizedDescription)")
        }

        // Check Keychain accessibility
        report.keychainAccessible = checkKeychainAccessibility()

        // Check biometric availability
        report.biometricAvailable = isBiometricAuthenticationAvailable()

        // Check for potential security issues
        report.securityIssues = detectSecurityIssues()

        return report
    }

    // MARK: - Private Methods

    private func createBaseQuery(for item: KeychainItem) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.account,
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func createSecureAttributes(for data: Data) -> [String: Any] {
        var attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        // Set accessibility based on security level
        switch securityLevel {
        case .standard:
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        case .high:
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly

        case .maximum:
            // Require biometric authentication for access
            if biometricPolicy == .required, isBiometricAuthenticationAvailable() {
                let access = SecAccessControlCreateWithFlags(
                    nil,
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    .biometryAny,
                    nil
                )
                attributes[kSecAttrAccessControl as String] = access
            } else {
                attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }

        return attributes
    }

    private func createLoadQuery(for item: KeychainItem) -> [String: Any] {
        var query = createBaseQuery(for: item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        // Add biometric prompt if required
        if securityLevel == .maximum, biometricPolicy == .required {
            query[kSecUseOperationPrompt as String] = "Access your wage information"
        }

        return query
    }

    private func encryptData(_ data: Data) throws -> Data {
        // For maximum security, we could implement additional encryption here
        // For now, we rely on Keychain's built-in encryption
        return data
    }

    private func decryptData(_ data: Data) throws -> Data {
        // Corresponding decryption for additional encryption
        return data
    }

    private func validateWageData(_ wage: WageData) throws {
        // Validate wage data integrity
        guard wage.amount > 0 else {
            throw KeychainError.invalidWageData("Wage amount must be positive")
        }

        guard !wage.currency.isEmpty else {
            throw KeychainError.invalidWageData("Currency cannot be empty")
        }

        guard wage.currency.count == 3 else {
            throw KeychainError.invalidWageData("Currency must be 3 characters")
        }

        // Check if wage is within reasonable bounds
        guard wage.amount <= 10000 else {
            throw KeychainError.invalidWageData("Wage amount exceeds maximum allowed")
        }

        // Validate timestamp is not in the future
        guard wage.lastUpdated <= Date() else {
            throw KeychainError.invalidWageData("Invalid timestamp")
        }

        // Validate timestamp is not too old (more than 10 years)
        let tenYearsAgo = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard wage.lastUpdated >= tenYearsAgo else {
            throw KeychainError.invalidWageData("Wage data is too old")
        }
    }

    private func checkKeychainAccessibility() -> Bool {
        // Try to perform a simple Keychain operation
        let testQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).test",
            kSecAttrAccount as String: "accessibility-test",
        ]

        // Try to delete any existing test item
        SecItemDelete(testQuery as CFDictionary)

        // Try to add a test item
        var testQueryWithData = testQuery
        testQueryWithData[kSecValueData as String] = "test".data(using: .utf8) ?? Data()
        testQueryWithData[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(testQueryWithData as CFDictionary, nil)

        if addStatus == errSecSuccess {
            // Clean up test item
            SecItemDelete(testQuery as CFDictionary)
            return true
        }

        return false
    }

    private func detectSecurityIssues() -> [String] {
        var issues: [String] = []

        // Check if device has passcode set
        let context = LAContext()
        var error: NSError?

        if !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            issues.append("Device passcode not set")
        }

        // Check if biometrics are available but not being used
        if securityLevel == .maximum, biometricPolicy == .optional, isBiometricAuthenticationAvailable() {
            issues.append("Biometric authentication available but not required")
        }

        // Check for jailbreak indicators (basic check)
        if isDeviceJailbroken() {
            issues.append("Device may be jailbroken - security compromised")
        }

        return issues
    }

    private func isDeviceJailbroken() -> Bool {
        // Basic jailbreak detection
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if we can write to system directories
        do {
            let testString = "jailbreak-test"
            try testString.write(toFile: "/private/test.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test.txt")
            return true // If we can write to /private, device might be jailbroken
        } catch {
            // Normal behavior - can't write to system directories
        }

        return false
    }

    private func logSecurityEvent(_ event: SecurityEvent, details: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
            os_log(
                .debug,
                "\u{1F512} Security Event [%{private}@]: %{public}@ - %{private}@",
                timestamp,
                event.rawValue,
                details
            )
        #endif

        // In production, you might want to log to a secure audit trail
        // or send to a security monitoring service
    }
}

// MARK: - Security Level

public enum SecurityLevel {
    case standard // Basic Keychain protection
    case high // Requires device passcode
    case maximum // Requires passcode + optional biometrics
}

// MARK: - Biometric Policy

public enum BiometricPolicy {
    case disabled // No biometric authentication
    case optional // Use biometrics if available
    case required // Require biometrics if available
}

// MARK: - Keychain Item

private enum KeychainItem {
    case wage

    var account: String {
        switch self {
        case .wage:
            return "user-wage-data"
        }
    }
}

// MARK: - Wage Data

public struct WageData: Codable {
    public let amount: Double
    public let currency: String
    public let period: PayPeriod
    public let lastUpdated: Date
    public let version: Int // For future migration compatibility

    public init(amount: Double, currency: String, period: PayPeriod) {
        self.amount = amount
        self.currency = currency
        self.period = period
        lastUpdated = Date()
        version = 1
    }
}

// MARK: - Pay Period

public enum PayPeriod: String, Codable, CaseIterable {
    case hourly
    case daily
    case weekly
    case monthly
    case yearly

    public var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    public var hoursMultiplier: Double {
        switch self {
        case .hourly: return 1.0
        case .daily: return 8.0
        case .weekly: return 40.0
        case .monthly: return 160.0
        case .yearly: return 2080.0
        }
    }
}

// MARK: - Keychain Error

public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    case invalidWageData(String)
    case biometricAuthenticationFailed
    case deviceNotSecure

    public var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            return "Failed to save to Keychain: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error")"
        case let .loadFailed(status):
            return "Failed to load from Keychain: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error")"
        case let .deleteFailed(status):
            return "Failed to delete from Keychain: \(SecCopyErrorMessageString(status, nil) ?? "Unknown error")"
        case .invalidData:
            return "Invalid data format in Keychain"
        case let .invalidWageData(reason):
            return "Invalid wage data: \(reason)"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        case .deviceNotSecure:
            return "Device security requirements not met"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .loadFailed, .deleteFailed:
            return "Please try again. If the problem persists, restart the app."
        case .invalidData, .invalidWageData:
            return "Please re-enter your wage information."
        case .biometricAuthenticationFailed:
            return "Please use your device passcode or try biometric authentication again."
        case .deviceNotSecure:
            return "Please set up a device passcode and enable biometric authentication."
        }
    }
}

// MARK: - Security Event

private enum SecurityEvent: String {
    case wageStored = "WAGE_STORED"
    case wageAccessed = "WAGE_ACCESSED"
    case wageDeleted = "WAGE_DELETED"
    case authenticationFailed = "AUTH_FAILED"
    case integrityCheckFailed = "INTEGRITY_FAILED"
    case securityIssueDetected = "SECURITY_ISSUE"
}

// MARK: - Keychain Integrity Report

public struct KeychainIntegrityReport {
    public var wageDataExists: Bool = false
    public var wageDataValid: Bool = false
    public var keychainAccessible: Bool = false
    public var biometricAvailable: Bool = false
    public var securityIssues: [String] = []
    public var errors: [String] = []

    public var isHealthy: Bool {
        return keychainAccessible && securityIssues.isEmpty && errors.isEmpty
    }

    public var securityScore: Double {
        var score = 0.0

        if keychainAccessible { score += 0.3 }
        if wageDataValid { score += 0.2 }
        if biometricAvailable { score += 0.2 }
        if securityIssues.isEmpty { score += 0.2 }
        if errors.isEmpty { score += 0.1 }

        return score
    }

    public var securityGrade: String {
        switch securityScore {
        case 0.9 ... 1.0: return "A+"
        case 0.8 ..< 0.9: return "A"
        case 0.7 ..< 0.8: return "B"
        case 0.6 ..< 0.7: return "C"
        case 0.5 ..< 0.6: return "D"
        default: return "F"
        }
    }
}

// MARK: - Keychain Manager Factory

public class KeychainManagerFactory {
    /// Create Keychain manager with appropriate security level based on device capabilities
    public static func createManager() -> HardenedKeychainManager {
        let context = LAContext()
        var error: NSError?

        // Determine appropriate security level
        let securityLevel: SecurityLevel
        let biometricPolicy: BiometricPolicy

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                securityLevel = .maximum
                biometricPolicy = .optional
            } else {
                securityLevel = .high
                biometricPolicy = .disabled
            }
        } else {
            securityLevel = .standard
            biometricPolicy = .disabled
        }

        // Return a new HardenedKeychainManager configured with the determined
        // security level and biometric policy instead of the shared instance.
        return HardenedKeychainManager(
            securityLevel: securityLevel,
            biometricPolicy: biometricPolicy
        )
    }
}
