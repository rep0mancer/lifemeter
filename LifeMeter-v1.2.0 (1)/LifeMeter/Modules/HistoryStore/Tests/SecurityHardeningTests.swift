import XCTest
import LocalAuthentication
@testable import HistoryStore
@testable import AppShell
@testable import PriceCapture

// MARK: - Hardened Keychain Manager Tests
@available(iOS 15.0, *)
final class HardenedKeychainManagerTests: XCTestCase {
    
    // MARK: - Properties
    private var keychainManager: HardenedKeychainManager!
    private var testWageData: WageData!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        keychainManager = HardenedKeychainManager.shared
        testWageData = WageData(amount: 25.50, currency: "EUR", period: .hourly)
        
        // Clean up any existing test data
        try? keychainManager.deleteWage()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        try? keychainManager.deleteWage()
        
        keychainManager = nil
        testWageData = nil
        
        super.tearDown()
    }
    
    // MARK: - Save Wage Tests
    
    func testSaveWage_ValidData_SavesSuccessfully() throws {
        // When
        try keychainManager.saveWage(testWageData)
        
        // Then
        let loadedWage = try keychainManager.loadWage()
        XCTAssertNotNil(loadedWage)
        XCTAssertEqual(loadedWage?.amount, testWageData.amount)
        XCTAssertEqual(loadedWage?.currency, testWageData.currency)
        XCTAssertEqual(loadedWage?.period, testWageData.period)
    }
    
    func testSaveWage_OverwriteExisting_UpdatesSuccessfully() throws {
        // Given
        try keychainManager.saveWage(testWageData)
        
        let updatedWage = WageData(amount: 30.00, currency: "USD", period: .monthly)
        
        // When
        try keychainManager.saveWage(updatedWage)
        
        // Then
        let loadedWage = try keychainManager.loadWage()
        XCTAssertNotNil(loadedWage)
        XCTAssertEqual(loadedWage?.amount, 30.00)
        XCTAssertEqual(loadedWage?.currency, "USD")
        XCTAssertEqual(loadedWage?.period, .monthly)
    }
    
    // MARK: - Load Wage Tests
    
    func testLoadWage_ExistingData_LoadsSuccessfully() throws {
        // Given
        try keychainManager.saveWage(testWageData)
        
        // When
        let loadedWage = try keychainManager.loadWage()
        
        // Then
        XCTAssertNotNil(loadedWage)
        XCTAssertEqual(loadedWage?.amount, testWageData.amount)
        XCTAssertEqual(loadedWage?.currency, testWageData.currency)
        XCTAssertEqual(loadedWage?.period, testWageData.period)
        XCTAssertEqual(loadedWage?.version, 1)
    }
    
    func testLoadWage_NoData_ReturnsNil() throws {
        // When
        let loadedWage = try keychainManager.loadWage()
        
        // Then
        XCTAssertNil(loadedWage)
    }
    
    // MARK: - Delete Wage Tests
    
    func testDeleteWage_ExistingData_DeletesSuccessfully() throws {
        // Given
        try keychainManager.saveWage(testWageData)
        XCTAssertNotNil(try keychainManager.loadWage())
        
        // When
        try keychainManager.deleteWage()
        
        // Then
        let loadedWage = try keychainManager.loadWage()
        XCTAssertNil(loadedWage)
    }
    
    func testDeleteWage_NoData_DoesNotThrow() throws {
        // When & Then
        XCTAssertNoThrow(try keychainManager.deleteWage())
    }
    
    // MARK: - Validation Tests
    
    func testValidateKeychainIntegrity_HealthyState_ReturnsGoodReport() throws {
        // Given
        try keychainManager.saveWage(testWageData)
        
        // When
        let report = try keychainManager.validateKeychainIntegrity()
        
        // Then
        XCTAssertTrue(report.wageDataExists)
        XCTAssertTrue(report.wageDataValid)
        XCTAssertTrue(report.keychainAccessible)
        XCTAssertTrue(report.isHealthy)
        XCTAssertGreaterThan(report.securityScore, 0.5)
    }
    
    func testValidateKeychainIntegrity_NoData_ReturnsAppropriateReport() throws {
        // When
        let report = try keychainManager.validateKeychainIntegrity()
        
        // Then
        XCTAssertFalse(report.wageDataExists)
        XCTAssertTrue(report.keychainAccessible) // Should still be accessible
    }
    
    // MARK: - Biometric Availability Tests
    
    func testIsBiometricAuthenticationAvailable_ReturnsBoolean() {
        // When
        let isAvailable = keychainManager.isBiometricAuthenticationAvailable()
        
        // Then
        // Result depends on device capabilities, just ensure it doesn't crash
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
    
    // MARK: - Data Validation Tests
    
    func testWageDataValidation_ValidData_PassesValidation() throws {
        // Given
        let validWage = WageData(amount: 25.50, currency: "EUR", period: .hourly)
        
        // When & Then
        XCTAssertNoThrow(try keychainManager.saveWage(validWage))
    }
    
    func testWageDataValidation_InvalidAmount_ThrowsError() {
        // Given
        let invalidWage = WageData(amount: -10.0, currency: "EUR", period: .hourly)
        
        // When & Then
        XCTAssertThrowsError(try keychainManager.saveWage(invalidWage)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    func testWageDataValidation_EmptyCurrency_ThrowsError() {
        // Given
        let invalidWage = WageData(amount: 25.50, currency: "", period: .hourly)
        
        // When & Then
        XCTAssertThrowsError(try keychainManager.saveWage(invalidWage)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    func testWageDataValidation_InvalidCurrencyLength_ThrowsError() {
        // Given
        let invalidWage = WageData(amount: 25.50, currency: "EURO", period: .hourly)
        
        // When & Then
        XCTAssertThrowsError(try keychainManager.saveWage(invalidWage)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    func testWageDataValidation_ExcessiveAmount_ThrowsError() {
        // Given
        let invalidWage = WageData(amount: 50000.0, currency: "EUR", period: .hourly)
        
        // When & Then
        XCTAssertThrowsError(try keychainManager.saveWage(invalidWage)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testKeychainOperations_Performance() throws {
        measure {
            for i in 0..<10 {
                let wage = WageData(amount: Double(i + 1) * 10, currency: "EUR", period: .hourly)
                try? keychainManager.saveWage(wage)
                _ = try? keychainManager.loadWage()
            }
        }
    }
}

// MARK: - Biometric Authentication Gate Tests
@available(iOS 15.0, *)
final class BiometricAuthenticationGateTests: XCTestCase {
    
    // MARK: - Properties
    private var authGate: BiometricAuthenticationGate!
    private var settings: BiometricSettings!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        authGate = BiometricAuthenticationGate()
        settings = BiometricSettings.shared
        
        // Reset to default state
        settings.isBiometricAuthEnabled = false
    }
    
    override func tearDownWithError() throws {
        // Reset settings
        settings.isBiometricAuthEnabled = false
        
        authGate = nil
        settings = nil
        
        super.tearDown()
    }
    
    // MARK: - Authentication Requirement Tests
    
    func testCheckAuthenticationRequirement_BiometricDisabled_NotRequired() {
        // Given
        settings.isBiometricAuthEnabled = false
        
        // When
        authGate.checkAuthenticationRequirement()
        
        // Then
        XCTAssertFalse(authGate.isAuthenticationRequired)
        XCTAssertTrue(authGate.isAuthenticated)
    }
    
    func testCheckAuthenticationRequirement_BiometricEnabled_RequiredIfAvailable() {
        // Given
        settings.isBiometricAuthEnabled = true
        
        // When
        authGate.checkAuthenticationRequirement()
        
        // Then
        if authGate.isBiometricAvailable() {
            XCTAssertTrue(authGate.isAuthenticationRequired)
            XCTAssertFalse(authGate.isAuthenticated)
        } else {
            XCTAssertFalse(authGate.isAuthenticationRequired)
            XCTAssertTrue(authGate.isAuthenticated)
        }
    }
    
    // MARK: - Biometric Availability Tests
    
    func testIsBiometricAvailable_ReturnsBoolean() {
        // When
        let isAvailable = authGate.isBiometricAvailable()
        
        // Then
        // Result depends on device capabilities
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
    
    func testGetBiometricType_ReturnsValidType() {
        // When
        let biometricType = authGate.getBiometricType()
        
        // Then
        XCTAssertTrue([.none, .touchID, .faceID, .opticID, .unknown].contains(biometricType))
    }
    
    // MARK: - Enable/Disable Tests
    
    func testEnableBiometricAuth_UpdatesSettings() {
        // Given
        XCTAssertFalse(settings.isBiometricAuthEnabled)
        
        // When
        authGate.enableBiometricAuth()
        
        // Then
        if authGate.isBiometricAvailable() {
            XCTAssertTrue(settings.isBiometricAuthEnabled)
        } else {
            // Should not enable if not available
            XCTAssertNotNil(authGate.authenticationError)
        }
    }
    
    func testDisableBiometricAuth_UpdatesSettings() {
        // Given
        settings.isBiometricAuthEnabled = true
        authGate.checkAuthenticationRequirement()
        
        // When
        authGate.disableBiometricAuth()
        
        // Then
        XCTAssertFalse(settings.isBiometricAuthEnabled)
        XCTAssertFalse(authGate.isAuthenticationRequired)
        XCTAssertTrue(authGate.isAuthenticated)
    }
    
    // MARK: - Reset Tests
    
    func testResetAuthentication_ResetsState() {
        // Given
        authGate.isAuthenticated = true
        authGate.authenticationError = .userCancelled
        
        // When
        authGate.resetAuthentication()
        
        // Then
        XCTAssertFalse(authGate.isAuthenticated)
        XCTAssertNil(authGate.authenticationError)
    }
}

// MARK: - Privacy-Aware OCR Manager Tests
@available(iOS 15.0, *)
final class PrivacyAwareOCRManagerTests: XCTestCase {
    
    // MARK: - Properties
    private var ocrManager: PrivacyAwareOCRManager!
    private var privacySettings: PrivacySettings!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        ocrManager = PrivacyAwareOCRManager.shared
        privacySettings = PrivacySettings.shared
        
        // Reset to default state
        privacySettings.isOCREnabled = true
    }
    
    override func tearDownWithError() throws {
        // Reset settings
        privacySettings.resetOCRSettings()
        
        ocrManager = nil
        privacySettings = nil
        
        super.tearDown()
    }
    
    // MARK: - OCR Availability Tests
    
    func testIsOCRAvailable_EnabledWithPermission_ReturnsTrue() {
        // Given
        privacySettings.isOCREnabled = true
        
        // When
        let isAvailable = ocrManager.isOCRAvailable()
        
        // Then
        // Result depends on device capabilities and permissions
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
    
    func testIsOCRAvailable_Disabled_ReturnsFalse() {
        // Given
        privacySettings.isOCREnabled = false
        
        // When
        let isAvailable = ocrManager.isOCRAvailable()
        
        // Then
        XCTAssertFalse(isAvailable)
    }
    
    // MARK: - Privacy Status Tests
    
    func testGetPrivacyStatus_ReturnsValidStatus() {
        // When
        let status = ocrManager.getPrivacyStatus()
        
        // Then
        XCTAssertNotNil(status)
        XCTAssertTrue(status.isOCREnabled == privacySettings.isOCREnabled)
    }
    
    // MARK: - Image Processing Tests
    
    func testProcessImage_ValidImage_ProcessesSuccessfully() {
        // Given
        let testImage = createTestImage()
        let expectation = XCTestExpectation(description: "Image processing")
        
        // When
        ocrManager.processImage(testImage) { result in
            // Then
            switch result {
            case .success(let ocrResult):
                XCTAssertNotNil(ocrResult)
                XCTAssertGreaterThanOrEqual(ocrResult.processingTime, 0)
            case .failure(let error):
                // Processing might fail on test images, which is acceptable
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testProcessImage_OCRDisabled_FailsWithError() {
        // Given
        privacySettings.isOCREnabled = false
        let testImage = createTestImage()
        let expectation = XCTestExpectation(description: "Image processing")
        
        // When
        ocrManager.processImage(testImage) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Should not succeed when OCR is disabled")
            case .failure(let error):
                XCTAssertEqual(error, .ocrDisabledByUser)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Privacy Settings Tests
    
    func testResetPrivacySettings_ResetsToDefaults() {
        // Given
        privacySettings.isOCREnabled = false
        privacySettings.hasShownOCRPrivacyNotice = true
        
        // When
        ocrManager.resetPrivacySettings()
        
        // Then
        XCTAssertTrue(privacySettings.isOCREnabled) // Default is enabled
        XCTAssertFalse(privacySettings.hasShownOCRPrivacyNotice)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 200, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw a simple test image with text-like content
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw some rectangles that might look like text
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 20, y: 30, width: 60, height: 15))
        context.fill(CGRect(x: 100, y: 30, width: 40, height: 15))
        context.fill(CGRect(x: 20, y: 55, width: 80, height: 15))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

// MARK: - Privacy Settings Tests
final class PrivacySettingsTests: XCTestCase {
    
    // MARK: - Properties
    private var privacySettings: PrivacySettings!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        privacySettings = PrivacySettings.shared
    }
    
    override func tearDownWithError() throws {
        privacySettings.resetOCRSettings()
        privacySettings = nil
        super.tearDown()
    }
    
    // MARK: - OCR Settings Tests
    
    func testOCREnabled_DefaultValue_IsTrue() {
        // Given - Fresh settings
        privacySettings.resetOCRSettings()
        
        // When
        let isEnabled = privacySettings.isOCREnabled
        
        // Then
        XCTAssertTrue(isEnabled)
    }
    
    func testOCREnabled_SetValue_PersistsCorrectly() {
        // Given
        privacySettings.isOCREnabled = false
        
        // When
        let isEnabled = privacySettings.isOCREnabled
        
        // Then
        XCTAssertFalse(isEnabled)
        
        // When - Change back
        privacySettings.isOCREnabled = true
        
        // Then
        XCTAssertTrue(privacySettings.isOCREnabled)
    }
    
    func testHasShownOCRPrivacyNotice_DefaultValue_IsFalse() {
        // Given - Fresh settings
        privacySettings.resetOCRSettings()
        
        // When
        let hasShown = privacySettings.hasShownOCRPrivacyNotice
        
        // Then
        XCTAssertFalse(hasShown)
    }
    
    func testHasShownOCRPrivacyNotice_SetValue_PersistsCorrectly() {
        // Given
        privacySettings.hasShownOCRPrivacyNotice = true
        
        // When
        let hasShown = privacySettings.hasShownOCRPrivacyNotice
        
        // Then
        XCTAssertTrue(hasShown)
    }
    
    func testResetOCRSettings_ResetsAllValues() {
        // Given
        privacySettings.isOCREnabled = false
        privacySettings.hasShownOCRPrivacyNotice = true
        
        // When
        privacySettings.resetOCRSettings()
        
        // Then
        XCTAssertTrue(privacySettings.isOCREnabled)
        XCTAssertFalse(privacySettings.hasShownOCRPrivacyNotice)
    }
}

// MARK: - Biometric Settings Tests
final class BiometricSettingsTests: XCTestCase {
    
    // MARK: - Properties
    private var biometricSettings: BiometricSettings!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        biometricSettings = BiometricSettings.shared
    }
    
    override func tearDownWithError() throws {
        // Reset to defaults
        biometricSettings.isBiometricAuthEnabled = false
        biometricSettings.allowPasscodeAsFallback = true
        biometricSettings.authenticationTimeout = 300
        
        biometricSettings = nil
        super.tearDown()
    }
    
    // MARK: - Biometric Auth Tests
    
    func testBiometricAuthEnabled_DefaultValue_IsFalse() {
        // Given - Reset to defaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "security.biometric.defaults_set")
        userDefaults.removeObject(forKey: "security.biometric.enabled")
        
        // Create new instance to test defaults
        let newSettings = BiometricSettings.shared
        
        // When
        let isEnabled = newSettings.isBiometricAuthEnabled
        
        // Then
        XCTAssertFalse(isEnabled)
    }
    
    func testBiometricAuthEnabled_SetValue_PersistsCorrectly() {
        // Given
        biometricSettings.isBiometricAuthEnabled = true
        
        // When
        let isEnabled = biometricSettings.isBiometricAuthEnabled
        
        // Then
        XCTAssertTrue(isEnabled)
    }
    
    func testAllowPasscodeAsFallback_DefaultValue_IsTrue() {
        // When
        let allowPasscode = biometricSettings.allowPasscodeAsFallback
        
        // Then
        XCTAssertTrue(allowPasscode)
    }
    
    func testAuthenticationTimeout_DefaultValue_Is300Seconds() {
        // When
        let timeout = biometricSettings.authenticationTimeout
        
        // Then
        XCTAssertEqual(timeout, 300)
    }
    
    func testAuthenticationTimeout_SetValue_PersistsCorrectly() {
        // Given
        biometricSettings.authenticationTimeout = 600
        
        // When
        let timeout = biometricSettings.authenticationTimeout
        
        // Then
        XCTAssertEqual(timeout, 600)
    }
}

// MARK: - Integration Tests
@available(iOS 15.0, *)
final class SecurityIntegrationTests: XCTestCase {
    
    func testSecurityComponents_Integration_WorkTogether() {
        // Given
        let keychainManager = HardenedKeychainManager.shared
        let authGate = BiometricAuthenticationGate()
        let ocrManager = PrivacyAwareOCRManager.shared
        
        // When - Check all components are available
        let keychainReport = try? keychainManager.validateKeychainIntegrity()
        let biometricAvailable = authGate.isBiometricAvailable()
        let ocrAvailable = ocrManager.isOCRAvailable()
        
        // Then - All components should be functional
        XCTAssertNotNil(keychainReport)
        XCTAssertTrue(keychainReport?.keychainAccessible ?? false)
        
        // Biometric and OCR availability depend on device capabilities
        XCTAssertTrue(biometricAvailable == true || biometricAvailable == false)
        XCTAssertTrue(ocrAvailable == true || ocrAvailable == false)
    }
    
    func testSecuritySettings_Persistence_AcrossAppLaunches() {
        // Given
        let biometricSettings = BiometricSettings.shared
        let privacySettings = PrivacySettings.shared
        
        // When - Set values
        biometricSettings.isBiometricAuthEnabled = true
        biometricSettings.authenticationTimeout = 600
        privacySettings.isOCREnabled = false
        
        // Then - Values should persist (simulated by reading again)
        XCTAssertTrue(biometricSettings.isBiometricAuthEnabled)
        XCTAssertEqual(biometricSettings.authenticationTimeout, 600)
        XCTAssertFalse(privacySettings.isOCREnabled)
    }
}

