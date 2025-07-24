import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Biometric Authentication Gate
@available(iOS 15.0, *)
public class BiometricAuthenticationGate: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated = false
    @Published public var authenticationError: AuthenticationError?
    @Published public var isAuthenticationRequired = false
    
    // MARK: - Properties
    private let context = LAContext()
    private let settings = BiometricSettings.shared
    
    // MARK: - Public Methods
    
    /// Check if authentication is required and available
    public func checkAuthenticationRequirement() {
        isAuthenticationRequired = settings.isBiometricAuthEnabled && isBiometricAvailable()
        
        if isAuthenticationRequired && !isAuthenticated {
            // Don't automatically authenticate - wait for user action
            isAuthenticated = false
        } else if !isAuthenticationRequired {
            // If not required, consider authenticated
            isAuthenticated = true
        }
    }
    
    /// Authenticate using biometrics or passcode
    public func authenticate(reason: String = "Access your financial data") {
        guard isAuthenticationRequired else {
            isAuthenticated = true
            return
        }
        
        guard isBiometricAvailable() else {
            authenticationError = .biometricNotAvailable
            return
        }
        
        let policy: LAPolicy = settings.allowPasscodeAsFallback ? 
            .deviceOwnerAuthentication : 
            .deviceOwnerAuthenticationWithBiometrics
        
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthenticated = true
                    self?.authenticationError = nil
                    self?.logAuthenticationEvent(.authenticationSucceeded)
                } else {
                    self?.isAuthenticated = false
                    self?.authenticationError = self?.mapAuthenticationError(error)
                    self?.logAuthenticationEvent(.authenticationFailed, details: error?.localizedDescription)
                }
            }
        }
    }
    
    /// Check if biometric authentication is available
    public func isBiometricAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Get available biometric type
    public func getBiometricType() -> BiometricType {
        guard isBiometricAvailable() else { return .none }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .unknown
        }
    }
    
    /// Reset authentication state
    public func resetAuthentication() {
        isAuthenticated = false
        authenticationError = nil
        checkAuthenticationRequirement()
    }
    
    /// Enable biometric authentication
    public func enableBiometricAuth() {
        guard isBiometricAvailable() else {
            authenticationError = .biometricNotAvailable
            return
        }
        
        settings.isBiometricAuthEnabled = true
        checkAuthenticationRequirement()
        logAuthenticationEvent(.biometricAuthEnabled)
    }
    
    /// Disable biometric authentication
    public func disableBiometricAuth() {
        settings.isBiometricAuthEnabled = false
        isAuthenticated = true // No longer required
        isAuthenticationRequired = false
        logAuthenticationEvent(.biometricAuthDisabled)
    }
    
    // MARK: - Private Methods
    
    private func mapAuthenticationError(_ error: Error?) -> AuthenticationError {
        guard let laError = error as? LAError else {
            return .unknown(error?.localizedDescription ?? "Unknown error")
        }
        
        switch laError.code {
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .userFallback:
            return .userChosePasscode
        case .systemCancel:
            return .systemCancelled
        case .passcodeNotSet:
            return .passcodeNotSet
        case .biometryNotAvailable:
            return .biometricNotAvailable
        case .biometryNotEnrolled:
            return .biometricNotEnrolled
        case .biometryLockout:
            return .biometricLockout
        case .appCancel:
            return .appCancelled
        case .invalidContext:
            return .invalidContext
        case .notInteractive:
            return .notInteractive
        default:
            return .unknown(laError.localizedDescription)
        }
    }
    
    private func logAuthenticationEvent(_ event: AuthenticationEvent, details: String? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = details != nil ? "\(event.rawValue) - \(details!)" : event.rawValue
        
        #if DEBUG
        print("🔐 Auth Event [\(timestamp)]: \(message)")
        #endif
        
        // In production, log to security audit trail
    }
}

// MARK: - Biometric Settings
public class BiometricSettings {
    
    // MARK: - Singleton
    public static let shared = BiometricSettings()
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    
    public var isBiometricAuthEnabled: Bool {
        get {
            return userDefaults.bool(forKey: "security.biometric.enabled")
        }
        set {
            userDefaults.set(newValue, forKey: "security.biometric.enabled")
        }
    }
    
    public var allowPasscodeAsFallback: Bool {
        get {
            return userDefaults.bool(forKey: "security.biometric.allow_passcode_fallback")
        }
        set {
            userDefaults.set(newValue, forKey: "security.biometric.allow_passcode_fallback")
        }
    }
    
    public var authenticationTimeout: TimeInterval {
        get {
            let timeout = userDefaults.double(forKey: "security.biometric.timeout")
            return timeout > 0 ? timeout : 300 // Default 5 minutes
        }
        set {
            userDefaults.set(newValue, forKey: "security.biometric.timeout")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Set default values
        if !userDefaults.bool(forKey: "security.biometric.defaults_set") {
            isBiometricAuthEnabled = false // Default to disabled for privacy
            allowPasscodeAsFallback = true
            authenticationTimeout = 300 // 5 minutes
            userDefaults.set(true, forKey: "security.biometric.defaults_set")
        }
    }
}

// MARK: - Biometric Authentication View
@available(iOS 15.0, *)
public struct BiometricAuthenticationView: View {
    
    // MARK: - Properties
    @StateObject private var authGate = BiometricAuthenticationGate()
    @State private var showingSettings = false
    
    let content: AnyView
    
    // MARK: - Initialization
    public init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    // MARK: - Body
    public var body: some View {
        Group {
            if authGate.isAuthenticated {
                content
            } else if authGate.isAuthenticationRequired {
                authenticationPromptView
            } else {
                content
            }
        }
        .onAppear {
            authGate.checkAuthenticationRequirement()
        }
        .sheet(isPresented: $showingSettings) {
            BiometricSettingsView(authGate: authGate)
        }
    }
    
    // MARK: - Authentication Prompt View
    @ViewBuilder
    private var authenticationPromptView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Biometric Icon
            Image(systemName: authGate.getBiometricType().iconName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Authentication Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Use \(authGate.getBiometricType().displayName) to access your financial data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Authentication Button
            Button(action: {
                authGate.authenticate()
            }) {
                HStack {
                    Image(systemName: authGate.getBiometricType().iconName)
                    Text("Authenticate")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            
            // Error Message
            if let error = authGate.authenticationError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Settings Button
            Button("Authentication Settings") {
                showingSettings = true
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Biometric Settings View
@available(iOS 15.0, *)
public struct BiometricSettingsView: View {
    
    // MARK: - Properties
    @ObservedObject var authGate: BiometricAuthenticationGate
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempBiometricEnabled: Bool
    @State private var tempAllowPasscode: Bool
    @State private var tempTimeout: Double
    
    // MARK: - Initialization
    public init(authGate: BiometricAuthenticationGate) {
        self.authGate = authGate
        
        let settings = BiometricSettings.shared
        self._tempBiometricEnabled = State(initialValue: settings.isBiometricAuthEnabled)
        self._tempAllowPasscode = State(initialValue: settings.allowPasscodeAsFallback)
        self._tempTimeout = State(initialValue: settings.authenticationTimeout)
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Enable Biometric Authentication", isOn: $tempBiometricEnabled)
                        .disabled(!authGate.isBiometricAvailable())
                    
                    if !authGate.isBiometricAvailable() {
                        Text("Biometric authentication is not available on this device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Require \(authGate.getBiometricType().displayName) to access your wage and financial data")
                }
                
                if tempBiometricEnabled {
                    Section {
                        Toggle("Allow Passcode as Fallback", isOn: $tempAllowPasscode)
                    } footer: {
                        Text("Allow device passcode when biometric authentication fails")
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Authentication Timeout")
                                .font(.subheadline)
                            
                            Slider(value: $tempTimeout, in: 60...3600, step: 60) {
                                Text("Timeout")
                            }
                            
                            Text("\(Int(tempTimeout / 60)) minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } footer: {
                        Text("How long to stay authenticated before requiring authentication again")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & Security")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Biometric data never leaves your device")
                        Text("• Authentication is handled by iOS securely")
                        Text("• You can disable this feature anytime")
                        Text("• Manual passcode entry is always available")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Privacy Information")
                }
            }
            .navigationTitle("Authentication Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        let settings = BiometricSettings.shared
        
        settings.isBiometricAuthEnabled = tempBiometricEnabled
        settings.allowPasscodeAsFallback = tempAllowPasscode
        settings.authenticationTimeout = tempTimeout
        
        if tempBiometricEnabled {
            authGate.enableBiometricAuth()
        } else {
            authGate.disableBiometricAuth()
        }
    }
}

// MARK: - Biometric Type
public enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    case unknown
    
    public var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        case .unknown:
            return "Biometric Authentication"
        }
    }
    
    public var iconName: String {
        switch self {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        case .unknown:
            return "biometric"
        }
    }
}

// MARK: - Authentication Error
public enum AuthenticationError: LocalizedError {
    case authenticationFailed
    case userCancelled
    case userChosePasscode
    case systemCancelled
    case passcodeNotSet
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricLockout
    case appCancelled
    case invalidContext
    case notInteractive
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancelled:
            return "Authentication was cancelled."
        case .userChosePasscode:
            return "User chose to enter passcode."
        case .systemCancelled:
            return "Authentication was cancelled by the system."
        case .passcodeNotSet:
            return "Device passcode is not set."
        case .biometricNotAvailable:
            return "Biometric authentication is not available."
        case .biometricNotEnrolled:
            return "No biometric data is enrolled on this device."
        case .biometricLockout:
            return "Biometric authentication is locked. Use your passcode."
        case .appCancelled:
            return "Authentication was cancelled by the app."
        case .invalidContext:
            return "Invalid authentication context."
        case .notInteractive:
            return "Authentication requires user interaction."
        case .unknown(let message):
            return "Authentication error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .authenticationFailed:
            return "Try authenticating again or use your device passcode."
        case .userCancelled, .systemCancelled, .appCancelled:
            return "Tap the authentication button to try again."
        case .passcodeNotSet:
            return "Set up a device passcode in Settings."
        case .biometricNotAvailable:
            return "Use manual authentication or disable biometric requirements."
        case .biometricNotEnrolled:
            return "Set up biometric authentication in Settings."
        case .biometricLockout:
            return "Enter your device passcode to unlock biometric authentication."
        default:
            return "Try again or contact support if the problem persists."
        }
    }
}

// MARK: - Authentication Event
private enum AuthenticationEvent: String {
    case authenticationSucceeded = "AUTH_SUCCEEDED"
    case authenticationFailed = "AUTH_FAILED"
    case biometricAuthEnabled = "BIOMETRIC_ENABLED"
    case biometricAuthDisabled = "BIOMETRIC_DISABLED"
    case authenticationTimeout = "AUTH_TIMEOUT"
}

// MARK: - Preview
@available(iOS 15.0, *)
struct BiometricAuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        BiometricAuthenticationView {
            VStack {
                Text("Protected Content")
                    .font(.title)
                Text("This content is protected by biometric authentication")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

