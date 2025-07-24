import XCTest
import SwiftUI
import Combine
@testable import HistoryStore
@testable import CalcCore
@testable import WageOnboarding
@testable import PriceCapture
@testable import CatRenderer
@testable import AppShell
@testable import TransactionLogger
@testable import TimeBudget
@testable import SocialSharing
@testable import ExchangeRates

// MARK: - LifeMeter Integration Tests
@available(iOS 15.0, *)
final class LifeMeterIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    private var testContext: NSManagedObjectContext!
    private var keychainManager: HardenedKeychainManager!
    private var conversionEngine: ConversionEngine!
    private var timeBudgetPlanner: TimeBudgetPlanner!
    private var exchangeRateManager: ExchangeRateManager!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        // Setup test environment
        testContext = createTestContext()
        keychainManager = HardenedKeychainManager.shared
        conversionEngine = ConversionEngine()
        timeBudgetPlanner = TimeBudgetPlanner()
        exchangeRateManager = ExchangeRateManager.shared
        
        // Clean up any existing test data
        try? keychainManager.deleteWage()
        cleanupTestData()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        try? keychainManager.deleteWage()
        cleanupTestData()
        
        testContext = nil
        keychainManager = nil
        conversionEngine = nil
        timeBudgetPlanner = nil
        exchangeRateManager = nil
        
        super.tearDown()
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteUserWorkflow_WageOnboardingToCalculation_WorksCorrectly() throws {
        // Phase 1: Wage Onboarding
        let wageData = WageData(amount: 25.0, currency: "EUR", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Verify wage is saved
        let savedWage = try keychainManager.loadWage()
        XCTAssertNotNil(savedWage)
        XCTAssertEqual(savedWage?.amount, 25.0)
        
        // Phase 2: Price Calculation
        let result = try conversionEngine.calculateWorkTime(
            price: 50.0,
            currency: "EUR",
            wageAmount: 25.0,
            wageCurrency: "EUR",
            wagePeriod: .hourly
        )
        
        XCTAssertEqual(result.workMinutes, 120.0) // 2 hours
        XCTAssertEqual(result.formattedTime, "2h 0m")
        
        // Phase 3: History Storage
        let historyEntry = HistoryEntry(context: testContext)
        historyEntry.calculationId = UUID()
        historyEntry.timestamp = Date()
        historyEntry.price = 50.0
        historyEntry.currency = "EUR"
        historyEntry.workMinutes = result.workMinutes
        historyEntry.source = .manual
        
        try testContext.save()
        
        // Verify history is saved
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        let entries = try testContext.fetch(fetchRequest)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.price, 50.0)
    }
    
    func testApplePayAutomation_EndToEnd_WorksCorrectly() throws {
        // Setup wage
        let wageData = WageData(amount: 30.0, currency: "USD", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Simulate Apple Pay transaction
        let transactionLogger = TransactionLogger()
        
        let result = try transactionLogger.processApplePayTransaction(
            amount: 15.0,
            currency: "USD",
            merchant: "Coffee Shop",
            cardName: "Apple Card"
        )
        
        XCTAssertEqual(result.workMinutes, 30.0) // 30 minutes
        XCTAssertEqual(result.formattedNotification, "$15.00 • 30m")
        
        // Verify history entry is created
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "source == %@", "applePay")
        
        let entries = try testContext.fetch(fetchRequest)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.price, 15.0)
        XCTAssertEqual(entries.first?.source, .applePay)
    }
    
    func testTimeBudgetIntegration_CreateAndTrack_WorksCorrectly() throws {
        // Setup wage
        let wageData = WageData(amount: 20.0, currency: "EUR", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Create budget
        let categories = [
            BudgetCategory(name: "Food", allocatedMinutes: 120, color: "#FF6B6B", icon: "fork.knife"),
            BudgetCategory(name: "Transport", allocatedMinutes: 60, color: "#4ECDC4", icon: "car.fill")
        ]
        
        try timeBudgetPlanner.createBudget(
            name: "Weekly Budget",
            totalWorkMinutes: 180, // 3 hours
            period: .weekly,
            categories: categories
        )
        
        // Track spending
        try timeBudgetPlanner.trackSpending(
            amount: 25.0, // 1.25 hours = 75 minutes
            currency: "EUR",
            category: "Food"
        )
        
        // Verify budget summary
        let summary = timeBudgetPlanner.getBudgetSummary()
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.totalUsedMinutes, 75.0)
        XCTAssertEqual(summary?.remainingMinutes, 105.0)
        XCTAssertFalse(summary?.isOverBudget ?? true)
        
        // Verify category spending
        let categorySpending = timeBudgetPlanner.getSpendingBreakdown()
        let foodCategory = categorySpending.first { $0.name == "Food" }
        XCTAssertNotNil(foodCategory)
        XCTAssertEqual(foodCategory?.usedMinutes, 75.0)
        XCTAssertEqual(foodCategory?.remainingMinutes, 45.0)
    }
    
    // MARK: - Security Integration Tests
    
    func testSecurityIntegration_BiometricAndKeychain_WorkTogether() throws {
        // Test hardened keychain with biometric settings
        let biometricSettings = BiometricSettings.shared
        biometricSettings.isBiometricAuthEnabled = true
        
        // Save wage with enhanced security
        let wageData = WageData(amount: 35.0, currency: "GBP", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Validate keychain integrity
        let integrityReport = try keychainManager.validateKeychainIntegrity()
        XCTAssertTrue(integrityReport.wageDataExists)
        XCTAssertTrue(integrityReport.wageDataValid)
        XCTAssertTrue(integrityReport.keychainAccessible)
        XCTAssertGreaterThan(integrityReport.securityScore, 0.5)
        
        // Test biometric authentication gate
        let authGate = BiometricAuthenticationGate()
        authGate.checkAuthenticationRequirement()
        
        // Should require authentication if biometric is available
        if authGate.isBiometricAvailable() {
            XCTAssertTrue(authGate.isAuthenticationRequired)
        }
    }
    
    func testPrivacyIntegration_OCRAndExchangeRates_RespectSettings() throws {
        // Test OCR privacy settings
        let ocrManager = PrivacyAwareOCRManager.shared
        let privacySettings = PrivacySettings.shared
        
        privacySettings.isOCREnabled = false
        XCTAssertFalse(ocrManager.isOCRAvailable())
        
        privacySettings.isOCREnabled = true
        // OCR availability depends on camera permission and device support
        
        // Test exchange rate privacy settings
        let exchangeSettings = ExchangeRateSettings.shared
        exchangeSettings.isExchangeRateEnabled = false
        exchangeSettings.hasUserConsent = false
        
        let rate = exchangeRateManager.getExchangeRate(from: "USD", to: "EUR")
        XCTAssertNil(rate) // Should be nil when disabled
        
        // Enable exchange rates
        exchangeRateManager.enableExchangeRates()
        XCTAssertTrue(exchangeSettings.isExchangeRateEnabled)
        XCTAssertTrue(exchangeSettings.hasUserConsent)
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformanceIntegration_LargeDataSets_PerformWell() throws {
        // Create large number of history entries
        let startTime = Date()
        
        for i in 0..<1000 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i * 60))
            entry.price = Double(i % 100) + 0.99
            entry.currency = ["EUR", "USD", "GBP"][i % 3]
            entry.workMinutes = Double(i % 120) + 5.0
            entry.source = [.manual, .applePay, .ocr][i % 3]
        }
        
        try testContext.save()
        
        let saveTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(saveTime, 5.0) // Should save 1000 entries in under 5 seconds
        
        // Test fetching performance
        let fetchStart = Date()
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 100
        
        let entries = try testContext.fetch(fetchRequest)
        let fetchTime = Date().timeIntervalSince(fetchStart)
        
        XCTAssertEqual(entries.count, 100)
        XCTAssertLessThan(fetchTime, 1.0) // Should fetch in under 1 second
    }
    
    func testCatAnimationPerformance_OptimizedRendering_PerformsWell() {
        // Test optimized cat animation performance
        let optimizer = CatAnimationOptimizer()
        
        measure {
            // Simulate multiple animation state changes
            for state in CatState.allCases {
                _ = optimizer.getOptimizedTexture(for: state)
            }
        }
    }
    
    // MARK: - Social Sharing Integration Tests
    
    func testSocialSharingIntegration_GenerateCards_WorksCorrectly() async throws {
        // Test calculation card generation
        let sharingManager = SocialSharingManager.shared
        
        let calculationCard = try await sharingManager.previewCard(
            price: 42.50,
            currency: "EUR",
            workTime: "1h 42m",
            template: .modern
        )
        
        XCTAssertNotNil(calculationCard)
        XCTAssertGreaterThan(calculationCard.size.width, 0)
        XCTAssertGreaterThan(calculationCard.size.height, 0)
        
        // Test budget card generation
        let summary = BudgetSummary(
            totalAllocatedMinutes: 480,
            totalUsedMinutes: 360,
            remainingMinutes: 120,
            usedPercentage: 0.75,
            isOverBudget: false
        )
        
        let budgetCardView = BudgetSharingCard(
            summary: summary,
            budgetName: "Monthly Budget",
            template: .budget
        )
        
        let cardGenerator = SharingCardGenerator()
        let budgetCard = try await cardGenerator.generateImage(from: budgetCardView)
        
        XCTAssertNotNil(budgetCard)
        XCTAssertGreaterThan(budgetCard.size.width, 0)
        XCTAssertGreaterThan(budgetCard.size.height, 0)
    }
    
    // MARK: - Exchange Rate Integration Tests
    
    func testExchangeRateIntegration_CurrencyConversion_WorksCorrectly() throws {
        // Setup test exchange rates
        exchangeRateManager.exchangeRates = [
            "USD_EUR": 0.85,
            "USD_GBP": 0.73,
            "EUR_GBP": 0.86
        ]
        
        // Test direct conversion
        let usdToEur = exchangeRateManager.convertCurrency(amount: 100.0, from: "USD", to: "EUR")
        XCTAssertEqual(usdToEur, 85.0)
        
        // Test inverse conversion
        let eurToUsd = exchangeRateManager.convertCurrency(amount: 85.0, from: "EUR", to: "USD")
        XCTAssertEqual(eurToUsd, 100.0, accuracy: 0.01)
        
        // Test conversion with wage calculation
        let wageData = WageData(amount: 25.0, currency: "USD", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Calculate work time for EUR price
        let result = try conversionEngine.calculateWorkTime(
            price: 42.5, // EUR
            currency: "EUR",
            wageAmount: 25.0, // USD
            wageCurrency: "USD",
            wagePeriod: .hourly
        )
        
        // Should convert EUR to USD first: 42.5 / 0.85 = 50 USD
        // Then calculate: 50 USD / 25 USD/hour = 2 hours = 120 minutes
        XCTAssertEqual(result.workMinutes, 120.0, accuracy: 1.0)
    }
    
    // MARK: - File-Based Attachment Integration Tests
    
    func testFileBasedAttachmentIntegration_StorageAndRetrieval_WorksCorrectly() throws {
        // Create test image
        let testImage = createTestImage()
        let attachmentManager = FileBasedAttachmentManager.shared
        
        // Create history entry with attachment
        let entry = HistoryEntry(context: testContext)
        entry.calculationId = UUID()
        entry.timestamp = Date()
        entry.price = 25.0
        entry.currency = "EUR"
        entry.workMinutes = 60.0
        entry.source = .ocr
        
        // Set attachment
        try entry.setAttachmentImage(testImage)
        try testContext.save()
        
        // Verify attachment is saved
        XCTAssertTrue(entry.hasAttachment)
        XCTAssertNotNil(entry.attachmentURL)
        XCTAssertNil(entry.photoData) // Legacy data should be cleared
        
        // Verify attachment can be loaded
        let loadedImage = entry.attachmentImage
        XCTAssertNotNil(loadedImage)
        
        // Test attachment statistics
        let statistics = attachmentManager.getAttachmentStatistics()
        XCTAssertEqual(statistics.totalAttachments, 1)
        XCTAssertGreaterThan(statistics.totalSize, 0)
        
        // Test cleanup
        try entry.removeAttachment()
        XCTAssertFalse(entry.hasAttachment)
        XCTAssertNil(entry.attachmentImage)
    }
    
    // MARK: - Widget Integration Tests
    
    func testWidgetIntegration_DataProvider_WorksCorrectly() throws {
        // Setup test data
        let wageData = WageData(amount: 30.0, currency: "EUR", period: .hourly)
        try keychainManager.saveWage(wageData)
        
        // Create recent calculations
        for i in 0..<5 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i * 3600))
            entry.price = Double(10 + i * 5)
            entry.currency = "EUR"
            entry.workMinutes = Double(20 + i * 10)
            entry.source = .manual
        }
        
        try testContext.save()
        
        // Test widget data provider
        let widgetDataProvider = WidgetDataProvider()
        let widgetData = try widgetDataProvider.getWidgetData()
        
        XCTAssertNotNil(widgetData.recentCalculation)
        XCTAssertEqual(widgetData.totalCalculations, 5)
        XCTAssertGreaterThan(widgetData.totalWorkTime, 0)
        
        // Test cat state for widget
        let catState = widgetDataProvider.getCatStateForWidget(totalMinutes: widgetData.totalWorkTime)
        XCTAssertTrue(CatState.allCases.contains(catState))
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingIntegration_GracefulDegradation_WorksCorrectly() throws {
        // Test calculation with missing wage
        XCTAssertThrowsError(try conversionEngine.calculateWorkTime(
            price: 50.0,
            currency: "EUR",
            wageAmount: 0.0,
            wageCurrency: "EUR",
            wagePeriod: .hourly
        )) { error in
            XCTAssertTrue(error is ConversionError)
        }
        
        // Test budget tracking without wage
        XCTAssertThrowsError(try timeBudgetPlanner.trackSpending(
            amount: 25.0,
            currency: "EUR",
            category: "Food"
        )) { error in
            XCTAssertTrue(error is TimeBudgetError)
        }
        
        // Test exchange rate without consent
        exchangeRateManager.disableExchangeRates()
        let rate = exchangeRateManager.getExchangeRate(from: "USD", to: "EUR")
        XCTAssertNil(rate)
        
        // Test OCR with disabled privacy settings
        let privacySettings = PrivacySettings.shared
        privacySettings.isOCREnabled = false
        
        let ocrManager = PrivacyAwareOCRManager.shared
        XCTAssertFalse(ocrManager.isOCRAvailable())
    }
    
    // MARK: - Data Migration Integration Tests
    
    func testDataMigrationIntegration_LegacyToNew_WorksCorrectly() throws {
        // Create legacy data (binary attachments)
        let testImage = createTestImage()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        
        let legacyEntry = HistoryEntry(context: testContext)
        legacyEntry.calculationId = UUID()
        legacyEntry.timestamp = Date()
        legacyEntry.price = 30.0
        legacyEntry.currency = "EUR"
        legacyEntry.workMinutes = 90.0
        legacyEntry.photoData = imageData // Legacy binary data
        
        try testContext.save()
        
        // Perform migration
        try AttachmentMigrationHelper.performMigration(context: testContext)
        
        // Verify migration
        let migrationResult = try AttachmentMigrationHelper.validateMigration(context: testContext)
        XCTAssertEqual(migrationResult.totalEntries, 1)
        XCTAssertEqual(migrationResult.entriesWithBinaryData, 0)
        XCTAssertEqual(migrationResult.entriesWithFileAttachments, 1)
        XCTAssertTrue(migrationResult.isFullyMigrated)
        
        // Verify entry after migration
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        let entries = try testContext.fetch(fetchRequest)
        let migratedEntry = entries.first!
        
        XCTAssertNotNil(migratedEntry.attachmentURL)
        XCTAssertNil(migratedEntry.photoData)
        XCTAssertTrue(migratedEntry.hasAttachment)
        XCTAssertNotNil(migratedEntry.attachmentImage)
    }
    
    // MARK: - Helper Methods
    
    private func createTestContext() -> NSManagedObjectContext {
        let model = NSManagedObjectModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        return context
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 25, y: 25, width: 50, height: 50))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func cleanupTestData() {
        // Clean up Core Data
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = HistoryEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? testContext.execute(deleteRequest)
        
        // Clean up file attachments
        let attachmentManager = FileBasedAttachmentManager.shared
        try? attachmentManager.cleanupOrphanedAttachments(validCalculationIds: Set())
        
        // Reset settings
        let privacySettings = PrivacySettings.shared
        privacySettings.resetOCRSettings()
        
        let biometricSettings = BiometricSettings.shared
        biometricSettings.isBiometricAuthEnabled = false
        
        let exchangeSettings = ExchangeRateSettings.shared
        exchangeSettings.isExchangeRateEnabled = false
        exchangeSettings.hasUserConsent = false
    }
}

// MARK: - Mock Widget Data Provider
class WidgetDataProvider {
    
    func getWidgetData() throws -> WidgetData {
        let context = PersistentContainer.shared.viewContext
        
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        let recentEntries = try context.fetch(fetchRequest)
        let recentCalculation = recentEntries.first
        
        let totalFetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        let totalEntries = try context.fetch(totalFetchRequest)
        
        let totalWorkTime = totalEntries.reduce(0) { $0 + $1.workMinutes }
        
        return WidgetData(
            recentCalculation: recentCalculation,
            totalCalculations: totalEntries.count,
            totalWorkTime: totalWorkTime
        )
    }
    
    func getCatStateForWidget(totalMinutes: Double) -> CatState {
        switch totalMinutes {
        case 0..<60:
            return .sleeping
        case 60..<180:
            return .resting
        case 180..<360:
            return .alert
        default:
            return .working
        }
    }
}

struct WidgetData {
    let recentCalculation: HistoryEntry?
    let totalCalculations: Int
    let totalWorkTime: Double
}

