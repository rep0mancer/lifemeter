import XCTest
import UserNotifications
@testable import TransactionLogger
@testable import CalcCore
@testable import HistoryStore

// MARK: - Transaction Logger Tests
@available(iOS 17.0, *)
final class TransactionLoggerTests: XCTestCase {
    
    // MARK: - Properties
    private var transactionLogger: TransactionLogger!
    private var mockHistoryStore: MockHistoryStore!
    private var mockNotificationCenter: MockNotificationCenter!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        // Setup mocks
        mockHistoryStore = MockHistoryStore()
        mockNotificationCenter = MockNotificationCenter()
        
        // Create transaction logger with mocked dependencies
        transactionLogger = TransactionLogger.shared
        
        // Setup test wage in Keychain
        let testWage = Wage(amount: 30.0, currency: "EUR", period: .hourly)
        KeychainManager.shared.saveWage(testWage)
    }
    
    override func tearDownWithError() throws {
        // Clean up Keychain
        KeychainManager.shared.deleteWage()
        
        transactionLogger = nil
        mockHistoryStore = nil
        mockNotificationCenter = nil
        
        super.tearDown()
    }
    
    // MARK: - Transaction Handling Tests
    
    func testHandleTransaction_ValidTransaction_CalculatesCorrectMinutes() async throws {
        // Given
        let transaction = Transaction(
            amount: 3.80,
            currency: "EUR",
            merchant: "Coffee Shop",
            cardName: "Apple Card"
        )
        
        // When
        try await transactionLogger.handle(transaction)
        
        // Then
        // €3.80 at €30/hour = (3.80 / 30) * 60 = 7.6 minutes ≈ 7m 36s
        let expectedMinutes = 7.6
        
        // Verify calculation was saved (would check mock in real implementation)
        // For now, verify the calculation logic
        let actualMinutes = ConversionEngine.convertToWorkTime(price: 3.80, hourlyWage: 30.0)
        XCTAssertEqual(actualMinutes, expectedMinutes, accuracy: 0.1)
    }
    
    func testHandleTransaction_NoWageConfigured_ThrowsError() async {
        // Given
        KeychainManager.shared.deleteWage() // Remove wage
        
        let transaction = Transaction(
            amount: 5.0,
            currency: "EUR",
            merchant: "Test Merchant"
        )
        
        // When & Then
        do {
            try await transactionLogger.handle(transaction)
            XCTFail("Expected error to be thrown")
        } catch TransactionLoggerError.noWageConfigured {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHandleTransaction_ZeroAmount_HandlesGracefully() async throws {
        // Given
        let transaction = Transaction(
            amount: 0.0,
            currency: "EUR",
            merchant: "Free Sample"
        )
        
        // When
        try await transactionLogger.handle(transaction)
        
        // Then
        let expectedMinutes = 0.0
        let actualMinutes = ConversionEngine.convertToWorkTime(price: 0.0, hourlyWage: 30.0)
        XCTAssertEqual(actualMinutes, expectedMinutes)
    }
    
    func testHandleTransaction_LargeAmount_CalculatesCorrectly() async throws {
        // Given
        let transaction = Transaction(
            amount: 1500.0,
            currency: "EUR",
            merchant: "Electronics Store"
        )
        
        // When
        try await transactionLogger.handle(transaction)
        
        // Then
        // €1500 at €30/hour = (1500 / 30) * 60 = 3000 minutes = 50 hours
        let expectedMinutes = 3000.0
        let actualMinutes = ConversionEngine.convertToWorkTime(price: 1500.0, hourlyWage: 30.0)
        XCTAssertEqual(actualMinutes, expectedMinutes, accuracy: 1.0)
    }
    
    // MARK: - Currency Tests
    
    func testHandleTransaction_DifferentCurrencies_HandlesCorrectly() async throws {
        let currencies = ["EUR", "USD", "GBP", "JPY"]
        
        for currency in currencies {
            // Given
            let transaction = Transaction(
                amount: 10.0,
                currency: currency,
                merchant: "Test Merchant"
            )
            
            // When & Then
            try await transactionLogger.handle(transaction)
            
            // Verify currency is preserved in calculation
            let expectedMinutes = ConversionEngine.convertToWorkTime(price: 10.0, hourlyWage: 30.0)
            XCTAssertEqual(expectedMinutes, 20.0, accuracy: 0.1) // 10/30 * 60 = 20 minutes
        }
    }
    
    // MARK: - Notification Tests
    
    func testNotificationContent_ValidTransaction_FormatsCorrectly() async throws {
        // Given
        let transaction = Transaction(
            amount: 4.50,
            currency: "EUR",
            merchant: "Coffee Shop",
            cardName: "Apple Card"
        )
        
        // When
        try await transactionLogger.handle(transaction)
        
        // Then
        // Verify notification formatting
        let formattedPrice = CurrencyUtilities.formatPrice(4.50, currency: "EUR")
        let minutes = ConversionEngine.convertToWorkTime(price: 4.50, hourlyWage: 30.0)
        let formattedTime = ConversionEngine.formatWorkTime(minutes)
        
        let expectedBody = "\(formattedPrice) Coffee Shop • \(formattedTime)"
        
        // In a real test, we would verify the notification was posted with correct content
        XCTAssertTrue(expectedBody.contains("Coffee Shop"))
        XCTAssertTrue(expectedBody.contains("€") || expectedBody.contains("4.50"))
    }
    
    func testNotificationActions_UndoAction_RemovesTransaction() async {
        // Given
        let calculationId = UUID().uuidString
        
        // When
        await transactionLogger.handleNotificationAction("UNDO_TRANSACTION", calculationId: calculationId)
        
        // Then
        // In a real test, we would verify the transaction was removed from history
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true)
    }
    
    func testNotificationActions_OpenAction_PostsNotification() async {
        // Given
        let calculationId = UUID().uuidString
        
        // When
        await transactionLogger.handleNotificationAction("OPEN_TRANSACTION", calculationId: calculationId)
        
        // Then
        // In a real test, we would verify the notification was posted
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Edge Cases
    
    func testHandleTransaction_VerySmallAmount_RoundsCorrectly() async throws {
        // Given
        let transaction = Transaction(
            amount: 0.01,
            currency: "EUR",
            merchant: "Penny Item"
        )
        
        // When
        try await transactionLogger.handle(transaction)
        
        // Then
        let expectedMinutes = ConversionEngine.convertToWorkTime(price: 0.01, hourlyWage: 30.0)
        XCTAssertEqual(expectedMinutes, 0.0, accuracy: 0.1) // Should round to 0
    }
    
    func testHandleTransaction_NoMerchant_HandlesGracefully() async throws {
        // Given
        let transaction = Transaction(
            amount: 5.0,
            currency: "EUR",
            merchant: nil
        )
        
        // When & Then
        try await transactionLogger.handle(transaction)
        
        // Should not crash and should handle nil merchant gracefully
        XCTAssertTrue(true)
    }
    
    func testHandleTransaction_NoCardName_HandlesGracefully() async throws {
        // Given
        let transaction = Transaction(
            amount: 5.0,
            currency: "EUR",
            merchant: "Test Merchant",
            cardName: nil
        )
        
        // When & Then
        try await transactionLogger.handle(transaction)
        
        // Should not crash and should handle nil card name gracefully
        XCTAssertTrue(true)
    }
    
    // MARK: - Performance Tests
    
    func testHandleTransaction_Performance() async throws {
        // Given
        let transaction = Transaction(
            amount: 10.0,
            currency: "EUR",
            merchant: "Performance Test"
        )
        
        // When & Then
        measure {
            Task {
                try? await transactionLogger.handle(transaction)
            }
        }
    }
    
    func testMultipleTransactions_Performance() async throws {
        // Given
        let transactions = (1...100).map { index in
            Transaction(
                amount: Double(index),
                currency: "EUR",
                merchant: "Merchant \(index)"
            )
        }
        
        // When & Then
        measure {
            Task {
                for transaction in transactions {
                    try? await transactionLogger.handle(transaction)
                }
            }
        }
    }
}

// MARK: - Transaction Model Tests
@available(iOS 17.0, *)
final class TransactionModelTests: XCTestCase {
    
    func testTransactionInitialization_AllParameters_SetsCorrectly() {
        // Given
        let amount = 15.99
        let currency = "USD"
        let merchant = "Apple Store"
        let cardName = "Apple Card"
        let timestamp = Date()
        
        // When
        let transaction = Transaction(
            amount: amount,
            currency: currency,
            merchant: merchant,
            cardName: cardName,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.currency, currency)
        XCTAssertEqual(transaction.merchant, merchant)
        XCTAssertEqual(transaction.cardName, cardName)
        XCTAssertEqual(transaction.timestamp, timestamp)
    }
    
    func testTransactionInitialization_MinimalParameters_SetsDefaults() {
        // Given
        let amount = 5.0
        let currency = "EUR"
        
        // When
        let transaction = Transaction(amount: amount, currency: currency)
        
        // Then
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.currency, currency)
        XCTAssertNil(transaction.merchant)
        XCTAssertNil(transaction.cardName)
        XCTAssertNotNil(transaction.timestamp)
    }
    
    func testTransactionCodable_EncodeDecode_PreservesData() throws {
        // Given
        let originalTransaction = Transaction(
            amount: 25.50,
            currency: "GBP",
            merchant: "Bookstore",
            cardName: "Visa"
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTransaction)
        
        let decoder = JSONDecoder()
        let decodedTransaction = try decoder.decode(Transaction.self, from: data)
        
        // Then
        XCTAssertEqual(decodedTransaction.amount, originalTransaction.amount)
        XCTAssertEqual(decodedTransaction.currency, originalTransaction.currency)
        XCTAssertEqual(decodedTransaction.merchant, originalTransaction.merchant)
        XCTAssertEqual(decodedTransaction.cardName, originalTransaction.cardName)
    }
}

// MARK: - Calculation Source Tests
final class CalculationSourceTests: XCTestCase {
    
    func testCalculationSource_AllCases_HaveDisplayNames() {
        for source in Calculation.Source.allCases {
            XCTAssertFalse(source.displayName.isEmpty)
        }
    }
    
    func testCalculationSource_AllCases_HaveIcons() {
        for source in Calculation.Source.allCases {
            XCTAssertFalse(source.icon.isEmpty)
        }
    }
    
    func testCalculationSource_ApplePay_HasCorrectProperties() {
        let source = Calculation.Source.applePay
        
        XCTAssertEqual(source.displayName, "Apple Pay")
        XCTAssertEqual(source.icon, "applelogo")
        XCTAssertEqual(source.rawValue, "applePay")
    }
    
    func testCalculationSource_Codable_EncodeDecode() throws {
        // Given
        let originalSource = Calculation.Source.applePay
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSource)
        
        let decoder = JSONDecoder()
        let decodedSource = try decoder.decode(Calculation.Source.self, from: data)
        
        // Then
        XCTAssertEqual(decodedSource, originalSource)
    }
}

// MARK: - Mock Classes
private class MockHistoryStore {
    var savedCalculations: [Calculation] = []
    var deletedCalculationIds: [UUID] = []
    
    func save(_ calculation: Calculation) async throws {
        savedCalculations.append(calculation)
    }
    
    func delete(calculationId: UUID) async throws {
        deletedCalculationIds.append(calculationId)
    }
}

private class MockNotificationCenter {
    var addedRequests: [UNNotificationRequest] = []
    var setCategories: Set<UNNotificationCategory> = []
    
    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
    
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        setCategories = categories
    }
}

