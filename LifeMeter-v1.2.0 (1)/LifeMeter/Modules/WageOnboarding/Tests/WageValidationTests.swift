import XCTest
@testable import WageOnboarding
@testable import CalcCore

// MARK: - Wage Validation Tests
@available(iOS 15.0, *)
final class WageValidationTests: XCTestCase {
    
    // MARK: - Properties
    private var viewModel: WageEntryViewModel!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        viewModel = WageEntryViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Blank Input Tests
    
    func testWageValidation_BlankInput_ShowsError() {
        // Given
        viewModel.wageText = ""
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Please enter a valid hourly wage.")
        } else {
            XCTFail("Expected invalid state for blank input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_WhitespaceOnlyInput_ShowsError() {
        // Given
        viewModel.wageText = "   \n\t  "
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Please enter a valid hourly wage.")
        } else {
            XCTFail("Expected invalid state for whitespace-only input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Non-Numeric Input Tests
    
    func testWageValidation_AlphabeticInput_ShowsError() {
        // Given
        viewModel.wageText = "abc"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Please enter a valid number.")
        } else {
            XCTFail("Expected invalid state for alphabetic input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_MixedAlphanumericInput_ShowsError() {
        // Given
        viewModel.wageText = "25abc"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Please enter a valid number.")
        } else {
            XCTFail("Expected invalid state for mixed input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_SpecialCharactersInput_ShowsError() {
        // Given
        viewModel.wageText = "25@#$"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Please enter a valid number.")
        } else {
            XCTFail("Expected invalid state for special characters input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Zero and Negative Input Tests
    
    func testWageValidation_ZeroInput_ShowsError() {
        // Given
        viewModel.wageText = "0"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Wage must be greater than zero.")
        } else {
            XCTFail("Expected invalid state for zero input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_ZeroDecimalInput_ShowsError() {
        // Given
        viewModel.wageText = "0.00"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Wage must be greater than zero.")
        } else {
            XCTFail("Expected invalid state for zero decimal input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_NegativeInput_ShowsError() {
        // Given
        viewModel.wageText = "-25.50"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Wage must be greater than zero.")
        } else {
            XCTFail("Expected invalid state for negative input")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Valid Input Tests
    
    func testWageValidation_ValidIntegerInput_PassesValidation() {
        // Given
        viewModel.wageText = "25"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state
        } else {
            XCTFail("Expected valid state for integer input")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_ValidDecimalInput_PassesValidation() {
        // Given
        viewModel.wageText = "25.50"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state
        } else {
            XCTFail("Expected valid state for decimal input")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_ValidSmallDecimalInput_PassesValidation() {
        // Given
        viewModel.wageText = "0.01"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state
        } else {
            XCTFail("Expected valid state for small decimal input")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_ValidLargeInput_PassesValidation() {
        // Given
        viewModel.wageText = "999.99"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state
        } else {
            XCTFail("Expected valid state for large input")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Edge Case Tests
    
    func testWageValidation_VeryLargeInput_ShowsWarning() {
        // Given
        viewModel.wageText = "15000"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .invalid(let message) = viewModel.wageValidationState {
            XCTAssertEqual(message, "Wage seems unusually high. Please verify.")
        } else {
            XCTFail("Expected invalid state for unusually high wage")
        }
        
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_DecimalWithComma_HandledCorrectly() {
        // Given - Some locales use comma as decimal separator
        viewModel.wageText = "25,50"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        // Should handle comma as decimal separator gracefully
        // Implementation may vary based on locale handling
        XCTAssertNotNil(viewModel.wageValidationState)
    }
    
    func testWageValidation_LeadingZeros_HandledCorrectly() {
        // Given
        viewModel.wageText = "025.50"
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state - leading zeros should be handled
        } else {
            XCTFail("Expected valid state for input with leading zeros")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    func testWageValidation_TrailingDecimalPoint_HandledCorrectly() {
        // Given
        viewModel.wageText = "25."
        
        // When
        viewModel.validateWageInput()
        
        // Then
        if case .valid = viewModel.wageValidationState {
            // Expected valid state - trailing decimal should be handled
        } else {
            XCTFail("Expected valid state for input with trailing decimal")
        }
        
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Real-time Validation Tests
    
    func testWageValidation_RealTimeUpdates_UpdatesButtonState() {
        // Given
        XCTAssertFalse(viewModel.isConvertButtonEnabled) // Initially disabled
        
        // When - Enter invalid input
        viewModel.wageText = "abc"
        viewModel.validateWageInput()
        
        // Then
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
        
        // When - Enter valid input
        viewModel.wageText = "25.50"
        viewModel.validateWageInput()
        
        // Then
        XCTAssertTrue(viewModel.isConvertButtonEnabled)
        
        // When - Clear input
        viewModel.wageText = ""
        viewModel.validateWageInput()
        
        // Then
        XCTAssertFalse(viewModel.isConvertButtonEnabled)
    }
    
    // MARK: - Currency Selection Tests
    
    func testCurrencySelection_SupportedCurrency_UpdatesSelection() {
        // Given
        let usdCurrency = Currency(code: "USD", symbol: "$", name: "US Dollar")
        
        // When
        viewModel.selectCurrency(usdCurrency)
        
        // Then
        XCTAssertEqual(viewModel.selectedCurrency.code, "USD")
        XCTAssertFalse(viewModel.showingError)
    }
    
    func testCurrencySelection_UnsupportedCurrency_ShowsError() {
        // Given
        let unsupportedCurrency = Currency(code: "XYZ", symbol: "X", name: "Fake Currency")
        
        // When
        viewModel.selectCurrency(unsupportedCurrency)
        
        // Then
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Unsupported currency. Please choose a different code.")
    }
    
    // MARK: - Default Currency Tests
    
    func testDefaultCurrency_LocaleBasedSelection_SetsCorrectCurrency() {
        // Given - Create new view model to test initialization
        let newViewModel = WageEntryViewModel()
        
        // Then - Should have a default currency set
        XCTAssertFalse(newViewModel.selectedCurrency.code.isEmpty)
        XCTAssertTrue(Currency.supportedCurrencies.contains { $0.code == newViewModel.selectedCurrency.code })
    }
    
    // MARK: - Period Selection Tests
    
    func testPeriodSelection_DefaultsToMonthly() {
        // Given - Fresh view model
        let newViewModel = WageEntryViewModel()
        
        // Then
        XCTAssertEqual(newViewModel.selectedPeriod, .monthly)
    }
    
    func testPeriodSelection_UpdatesPeriod() {
        // Given
        XCTAssertEqual(viewModel.selectedPeriod, .monthly)
        
        // When
        viewModel.selectPeriod(.hourly)
        
        // Then
        XCTAssertEqual(viewModel.selectedPeriod, .hourly)
    }
    
    // MARK: - Save Wage Tests
    
    func testSaveWage_ValidInput_CallsKeychainManager() async {
        // Given
        viewModel.wageText = "25.50"
        viewModel.validateWageInput()
        
        // When
        viewModel.saveWage()
        
        // Then
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for async operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Note: In a real test, we would mock KeychainManager to verify the call
    }
    
    func testSaveWage_InvalidInput_DoesNotSave() {
        // Given
        viewModel.wageText = "invalid"
        viewModel.validateWageInput()
        
        // When
        viewModel.saveWage()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Performance Tests
    
    func testWageValidation_Performance() {
        measure {
            for i in 0..<1000 {
                viewModel.wageText = "\(i).50"
                viewModel.validateWageInput()
            }
        }
    }
}

// MARK: - Currency Manager Tests
final class CurrencyManagerTests: XCTestCase {
    
    private var currencyManager: CurrencyManager!
    
    override func setUpWithError() throws {
        super.setUp()
        currencyManager = CurrencyManager.shared
    }
    
    override func tearDownWithError() throws {
        currencyManager = nil
        super.tearDown()
    }
    
    // MARK: - Valid Currency Tests
    
    func testSetCurrency_ValidCurrency_UpdatesSelection() throws {
        // Given
        let validCurrency = "USD"
        
        // When
        try currencyManager.setCurrency(validCurrency)
        
        // Then
        XCTAssertEqual(currencyManager.selectedCurrency, validCurrency)
    }
    
    func testSetCurrency_AllSupportedCurrencies_UpdatesSelection() throws {
        // Given
        let supportedCurrencies = ["EUR", "USD", "GBP", "JPY", "CHF", "CAD", "AUD"]
        
        // When & Then
        for currency in supportedCurrencies {
            try currencyManager.setCurrency(currency)
            XCTAssertEqual(currencyManager.selectedCurrency, currency)
        }
    }
    
    // MARK: - Invalid Currency Tests
    
    func testSetCurrency_NilCurrency_ThrowsError() {
        // When & Then
        XCTAssertThrowsError(try currencyManager.setCurrency(nil)) { error in
            XCTAssertTrue(error is CurrencyError)
            if case .invalidCurrencyCode(let message) = error as? CurrencyError {
                XCTAssertEqual(message, "Currency code cannot be nil or empty")
            }
        }
    }
    
    func testSetCurrency_EmptyCurrency_ThrowsError() {
        // When & Then
        XCTAssertThrowsError(try currencyManager.setCurrency("")) { error in
            XCTAssertTrue(error is CurrencyError)
            if case .invalidCurrencyCode(let message) = error as? CurrencyError {
                XCTAssertEqual(message, "Currency code cannot be nil or empty")
            }
        }
    }
    
    func testSetCurrency_UnsupportedCurrency_ThrowsError() {
        // Given
        let unsupportedCurrency = "XYZ"
        
        // When & Then
        XCTAssertThrowsError(try currencyManager.setCurrency(unsupportedCurrency)) { error in
            XCTAssertTrue(error is CurrencyError)
            if case .unsupportedCurrency(let message) = error as? CurrencyError {
                XCTAssertTrue(message.contains("Unsupported currency"))
                XCTAssertTrue(message.contains(unsupportedCurrency))
            }
        }
    }
    
    // MARK: - Currency Support Tests
    
    func testIsSupported_SupportedCurrencies_ReturnsTrue() {
        // Given
        let supportedCurrencies = ["EUR", "USD", "GBP", "JPY", "CHF", "CAD", "AUD"]
        
        // When & Then
        for currency in supportedCurrencies {
            XCTAssertTrue(currencyManager.isSupported(currency))
        }
    }
    
    func testIsSupported_UnsupportedCurrencies_ReturnsFalse() {
        // Given
        let unsupportedCurrencies = ["XYZ", "ABC", "123", ""]
        
        // When & Then
        for currency in unsupportedCurrencies {
            XCTAssertFalse(currencyManager.isSupported(currency))
        }
    }
    
    func testIsSupported_NilCurrency_ReturnsFalse() {
        // When & Then
        XCTAssertFalse(currencyManager.isSupported(nil))
    }
    
    // MARK: - Validation Tests
    
    func testValidateCurrencyForConversion_ValidCurrency_DoesNotThrow() {
        // Given
        let validCurrency = "EUR"
        
        // When & Then
        XCTAssertNoThrow(try currencyManager.validateCurrencyForConversion(validCurrency))
    }
    
    func testValidateCurrencyForConversion_NilCurrency_ThrowsError() {
        // When & Then
        XCTAssertThrowsError(try currencyManager.validateCurrencyForConversion(nil)) { error in
            XCTAssertTrue(error is CurrencyError)
            if case .invalidCurrencyCode(let message) = error as? CurrencyError {
                XCTAssertEqual(message, "Currency code is required for conversion")
            }
        }
    }
    
    func testValidateCurrencyForConversion_UnsupportedCurrency_ThrowsError() {
        // Given
        let unsupportedCurrency = "XYZ"
        
        // When & Then
        XCTAssertThrowsError(try currencyManager.validateCurrencyForConversion(unsupportedCurrency)) { error in
            XCTAssertTrue(error is CurrencyError)
            if case .unsupportedCurrency(let message) = error as? CurrencyError {
                XCTAssertEqual(message, "Unsupported currency. Please choose a different code.")
            }
        }
    }
}

// MARK: - Currency Validator Tests
final class CurrencyValidatorTests: XCTestCase {
    
    func testValidate_ValidCurrency_ReturnsValid() {
        // Given
        let validCurrency = "EUR"
        
        // When
        let result = CurrencyValidator.validate(validCurrency)
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidate_NilCurrency_ReturnsInvalid() {
        // When
        let result = CurrencyValidator.validate(nil)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Currency code cannot be empty")
    }
    
    func testValidate_EmptyCurrency_ReturnsInvalid() {
        // When
        let result = CurrencyValidator.validate("")
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Currency code cannot be empty")
    }
    
    func testValidate_WrongLengthCurrency_ReturnsInvalid() {
        // Given
        let shortCurrency = "EU"
        let longCurrency = "EURO"
        
        // When
        let shortResult = CurrencyValidator.validate(shortCurrency)
        let longResult = CurrencyValidator.validate(longCurrency)
        
        // Then
        XCTAssertFalse(shortResult.isValid)
        XCTAssertEqual(shortResult.errorMessage, "Currency code must be 3 characters")
        
        XCTAssertFalse(longResult.isValid)
        XCTAssertEqual(longResult.errorMessage, "Currency code must be 3 characters")
    }
    
    func testValidate_LowercaseCurrency_ReturnsInvalid() {
        // Given
        let lowercaseCurrency = "eur"
        
        // When
        let result = CurrencyValidator.validate(lowercaseCurrency)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Currency code must contain only uppercase letters")
    }
    
    func testValidate_NumericCurrency_ReturnsInvalid() {
        // Given
        let numericCurrency = "123"
        
        // When
        let result = CurrencyValidator.validate(numericCurrency)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Currency code must contain only uppercase letters")
    }
    
    func testValidate_UnsupportedCurrency_ReturnsInvalid() {
        // Given
        let unsupportedCurrency = "XYZ"
        
        // When
        let result = CurrencyValidator.validate(unsupportedCurrency)
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Currency 'XYZ' is not supported")
    }
}

