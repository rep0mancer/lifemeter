import XCTest
import CoreData
import SwiftUI
@testable import HistoryStore
@testable import CalcCore
@testable import CatRenderer
@testable import TimeBudget
@testable import SocialSharing
@testable import ExchangeRates

// MARK: - LifeMeter Performance Tests
@available(iOS 15.0, *)
final class LifeMeterPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    private var testContext: NSManagedObjectContext!
    private var conversionEngine: ConversionEngine!
    private var attachmentManager: FileBasedAttachmentManager!
    private var timeBudgetPlanner: TimeBudgetPlanner!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        testContext = createTestContext()
        conversionEngine = ConversionEngine()
        attachmentManager = FileBasedAttachmentManager.shared
        timeBudgetPlanner = TimeBudgetPlanner()
        
        // Clean up any existing test data
        cleanupTestData()
    }
    
    override func tearDownWithError() throws {
        cleanupTestData()
        
        testContext = nil
        conversionEngine = nil
        attachmentManager = nil
        timeBudgetPlanner = nil
        
        super.tearDown()
    }
    
    // MARK: - Core Data Performance Tests
    
    func testCoreDataPerformance_BulkInsert_PerformsWell() throws {
        measure {
            for i in 0..<1000 {
                let entry = HistoryEntry(context: testContext)
                entry.calculationId = UUID()
                entry.timestamp = Date().addingTimeInterval(TimeInterval(-i))
                entry.price = Double(i % 100) + 0.99
                entry.currency = ["EUR", "USD", "GBP", "JPY", "CAD"][i % 5]
                entry.workMinutes = Double(i % 480) + 1.0
                entry.source = [.manual, .applePay, .ocr][i % 3]
            }
            
            try! testContext.save()
        }
    }
    
    func testCoreDataPerformance_BulkFetch_PerformsWell() throws {
        // Setup test data
        for i in 0..<5000 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i * 60))
            entry.price = Double(i % 200) + 0.99
            entry.currency = ["EUR", "USD", "GBP", "JPY", "CAD", "AUD", "CHF"][i % 7]
            entry.workMinutes = Double(i % 600) + 1.0
            entry.source = [.manual, .applePay, .ocr][i % 3]
        }
        
        try testContext.save()
        
        // Test fetch performance
        measure {
            let fetchRequest: NSFetchRequest = HistoryEntry.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
            fetchRequest.fetchLimit = 100
            
            _ = try! testContext.fetch(fetchRequest)
        }
    }
    
    func testCoreDataPerformance_ComplexQuery_PerformsWell() throws {
        // Setup test data
        let currencies = ["EUR", "USD", "GBP", "JPY", "CAD"]
        let sources: [CalculationSource] = [.manual, .applePay, .ocr]
        
        for i in 0..<2000 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i * 3600)) // Hourly intervals
            entry.price = Double.random(in: 1.0...500.0)
            entry.currency = currencies[i % currencies.count]
            entry.workMinutes = Double.random(in: 1.0...480.0)
            entry.source = sources[i % sources.count]
        }
        
        try testContext.save()
        
        // Test complex query performance
        measure {
            let fetchRequest: NSFetchRequest = HistoryEntry.fetchRequest()
            
            // Complex predicate: last 30 days, EUR currency, price > 50
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
            fetchRequest.predicate = NSPredicate(format: "timestamp >= %@ AND currency == %@ AND price > %@", 
                                                thirtyDaysAgo as NSDate, "EUR", NSNumber(value: 50.0))
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)]
            
            _ = try! testContext.fetch(fetchRequest)
        }
    }
    
    func testCoreDataPerformance_BatchDelete_PerformsWell() throws {
        // Setup test data
        for i in 0..<3000 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i * 60))
            entry.price = Double(i % 100) + 0.99
            entry.currency = "EUR"
            entry.workMinutes = Double(i % 120) + 1.0
            entry.source = .manual
        }
        
        try testContext.save()
        
        // Test batch delete performance
        measure {
            let fetchRequest: NSFetchRequest = HistoryEntry.fetchRequest()
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", oneWeekAgo as NSDate)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try! testContext.execute(deleteRequest)
        }
    }
    
    // MARK: - Calculation Engine Performance Tests
    
    func testCalculationEngine_BulkCalculations_PerformsWell() {
        let testCases = (0..<1000).map { i in
            (price: Double(i % 500) + 0.99,
             currency: ["EUR", "USD", "GBP"][i % 3],
             wage: Double(i % 50) + 10.0,
             wageCurrency: ["EUR", "USD", "GBP"][i % 3])
        }
        
        measure {
            for testCase in testCases {
                _ = try! conversionEngine.calculateWorkTime(
                    price: testCase.price,
                    currency: testCase.currency,
                    wageAmount: testCase.wage,
                    wageCurrency: testCase.wageCurrency,
                    wagePeriod: .hourly
                )
            }
        }
    }
    
    func testCalculationEngine_CurrencyConversion_PerformsWell() {
        // Setup exchange rates
        let exchangeRates: [String: Double] = [
            "USD_EUR": 0.85,
            "USD_GBP": 0.73,
            "USD_JPY": 110.0,
            "USD_CAD": 1.25,
            "USD_AUD": 1.35,
            "USD_CHF": 0.92
        ]
        
        let currencyManager = CurrencyManager()
        currencyManager.updateExchangeRates(exchangeRates)
        
        let testCases = (0..<500).map { i in
            (amount: Double(i % 1000) + 1.0,
             from: ["USD", "EUR", "GBP", "JPY"][i % 4],
             to: ["EUR", "USD", "GBP", "CAD"][i % 4])
        }
        
        measure {
            for testCase in testCases {
                _ = currencyManager.convertCurrency(
                    amount: testCase.amount,
                    from: testCase.from,
                    to: testCase.to
                )
            }
        }
    }
    
    // MARK: - File-Based Attachment Performance Tests
    
    func testFileAttachments_BulkSave_PerformsWell() {
        let testImages = (0..<100).map { _ in createTestImage() }
        let testIds = (0..<100).map { _ in UUID() }
        
        measure {
            for (image, id) in zip(testImages, testIds) {
                try! attachmentManager.saveAttachment(image, for: id)
            }
        }
    }
    
    func testFileAttachments_BulkLoad_PerformsWell() {
        // Setup test attachments
        let testImages = (0..<50).map { _ in createTestImage() }
        let testIds = (0..<50).map { _ in UUID() }
        var fileURLs: [URL] = []
        
        for (image, id) in zip(testImages, testIds) {
            let url = try! attachmentManager.saveAttachment(image, for: id)
            fileURLs.append(url)
        }
        
        // Test loading performance
        measure {
            for url in fileURLs {
                _ = attachmentManager.loadAttachment(from: url)
            }
        }
    }
    
    func testFileAttachments_Statistics_PerformsWell() {
        // Setup test attachments
        for _ in 0..<200 {
            let image = createTestImage()
            let id = UUID()
            try! attachmentManager.saveAttachment(image, for: id)
        }
        
        // Test statistics calculation performance
        measure {
            _ = attachmentManager.getAttachmentStatistics()
        }
    }
    
    func testFileAttachments_Cleanup_PerformsWell() {
        // Setup test attachments
        var validIds: Set<UUID> = []
        
        for i in 0..<300 {
            let image = createTestImage()
            let id = UUID()
            try! attachmentManager.saveAttachment(image, for: id)
            
            // Keep only half as "valid"
            if i % 2 == 0 {
                validIds.insert(id)
            }
        }
        
        // Test cleanup performance
        measure {
            try! attachmentManager.cleanupOrphanedAttachments(validCalculationIds: validIds)
        }
    }
    
    // MARK: - Cat Animation Performance Tests
    
    func testCatAnimation_TexturePreCaching_PerformsWell() {
        let optimizer = CatAnimationOptimizer()
        
        measure {
            // Pre-cache all cat states
            for state in CatState.allCases {
                _ = optimizer.getOptimizedTexture(for: state)
            }
        }
    }
    
    func testCatAnimation_StateTransitions_PerformsWell() {
        let optimizer = CatAnimationOptimizer()
        
        // Pre-cache textures
        for state in CatState.allCases {
            _ = optimizer.getOptimizedTexture(for: state)
        }
        
        // Test rapid state transitions
        measure {
            for _ in 0..<1000 {
                let randomState = CatState.allCases.randomElement()!
                _ = optimizer.getOptimizedTexture(for: randomState)
            }
        }
    }
    
    func testCatAnimation_WidgetSnapshot_PerformsWell() {
        let snapshotGenerator = WidgetSnapshotGenerator()
        
        measure {
            for state in CatState.allCases {
                _ = snapshotGenerator.generateSnapshot(for: state, size: CGSize(width: 100, height: 100))
            }
        }
    }
    
    // MARK: - Time Budget Performance Tests
    
    func testTimeBudget_BulkBudgetCreation_PerformsWell() {
        let categories = [
            BudgetCategory(name: "Food", allocatedMinutes: 120, color: "#FF6B6B", icon: "fork.knife"),
            BudgetCategory(name: "Transport", allocatedMinutes: 60, color: "#4ECDC4", icon: "car.fill"),
            BudgetCategory(name: "Entertainment", allocatedMinutes: 90, color: "#45B7D1", icon: "gamecontroller.fill"),
            BudgetCategory(name: "Shopping", allocatedMinutes: 150, color: "#96CEB4", icon: "bag.fill")
        ]
        
        measure {
            for i in 0..<100 {
                try! timeBudgetPlanner.createBudget(
                    name: "Budget \(i)",
                    totalWorkMinutes: 480, // 8 hours
                    period: .weekly,
                    categories: categories
                )
            }
        }
    }
    
    func testTimeBudget_BulkSpendingTracking_PerformsWell() {
        // Setup a budget
        let categories = [
            BudgetCategory(name: "Food", allocatedMinutes: 240, color: "#FF6B6B", icon: "fork.knife"),
            BudgetCategory(name: "Transport", allocatedMinutes: 120, color: "#4ECDC4", icon: "car.fill")
        ]
        
        try! timeBudgetPlanner.createBudget(
            name: "Performance Test Budget",
            totalWorkMinutes: 480,
            period: .weekly,
            categories: categories
        )
        
        // Setup wage for calculations
        let keychainManager = HardenedKeychainManager.shared
        let wageData = WageData(amount: 25.0, currency: "EUR", period: .hourly)
        try! keychainManager.saveWage(wageData)
        
        // Test bulk spending tracking
        measure {
            for i in 0..<500 {
                let amount = Double(i % 50) + 1.0
                let category = ["Food", "Transport"][i % 2]
                
                try! timeBudgetPlanner.trackSpending(
                    amount: amount,
                    currency: "EUR",
                    category: category
                )
            }
        }
        
        // Cleanup
        try! keychainManager.deleteWage()
    }
    
    func testTimeBudget_SummaryCalculation_PerformsWell() {
        // Setup budget with many spending entries
        let categories = [
            BudgetCategory(name: "Food", allocatedMinutes: 240, color: "#FF6B6B", icon: "fork.knife"),
            BudgetCategory(name: "Transport", allocatedMinutes: 120, color: "#4ECDC4", icon: "car.fill"),
            BudgetCategory(name: "Entertainment", allocatedMinutes: 180, color: "#45B7D1", icon: "gamecontroller.fill")
        ]
        
        try! timeBudgetPlanner.createBudget(
            name: "Summary Test Budget",
            totalWorkMinutes: 600,
            period: .weekly,
            categories: categories
        )
        
        // Add many spending entries
        let keychainManager = HardenedKeychainManager.shared
        let wageData2 = WageData(amount: 20.0, currency: "EUR", period: .hourly)
        try! keychainManager.saveWage(wageData2)
        
        for i in 0..<1000 {
            let amount = Double(i % 30) + 1.0
            let category = ["Food", "Transport", "Entertainment"][i % 3]
            
            try! timeBudgetPlanner.trackSpending(
                amount: amount,
                currency: "EUR",
                category: category
            )
        }
        
        // Test summary calculation performance
        measure {
            _ = timeBudgetPlanner.getBudgetSummary()
            _ = timeBudgetPlanner.getSpendingBreakdown()
            _ = timeBudgetPlanner.getBudgetProgress()
        }
        
        // Cleanup
        try! keychainManager.deleteWage()
    }
    
    // MARK: - Social Sharing Performance Tests
    
    func testSocialSharing_CardGeneration_PerformsWell() async {
        let sharingManager = SocialSharingManager.shared
        
        await measure {
            for template in SharingTemplate.allCases {
                _ = try! await sharingManager.previewCard(
                    price: 42.50,
                    currency: "EUR",
                    workTime: "1h 42m",
                    template: template
                )
            }
        }
    }
    
    func testSocialSharing_BulkCardGeneration_PerformsWell() async {
        let cardGenerator = SharingCardGenerator()
        
        await measure {
            for i in 0..<50 {
                let cardView = CalculationSharingCard(
                    price: Double(i % 100) + 0.99,
                    currency: "EUR",
                    workTime: "\(i % 5)h \(i % 60)m",
                    template: .modern
                )
                
                _ = try! await cardGenerator.generateImage(from: cardView)
            }
        }
    }
    
    // MARK: - Exchange Rate Performance Tests
    
    func testExchangeRate_BulkConversion_PerformsWell() {
        let exchangeManager = ExchangeRateManager.shared
        
        // Setup test exchange rates
        exchangeManager.exchangeRates = [
            "USD_EUR": 0.85,
            "USD_GBP": 0.73,
            "USD_JPY": 110.0,
            "USD_CAD": 1.25,
            "USD_AUD": 1.35,
            "USD_CHF": 0.92,
            "EUR_GBP": 0.86,
            "EUR_JPY": 129.4,
            "GBP_JPY": 150.7
        ]
        
        let testCases = (0..<1000).map { i in
            (amount: Double(i % 1000) + 1.0,
             from: ["USD", "EUR", "GBP", "JPY"][i % 4],
             to: ["EUR", "USD", "GBP", "CAD"][i % 4])
        }
        
        measure {
            for testCase in testCases {
                _ = exchangeManager.convertCurrency(
                    amount: testCase.amount,
                    from: testCase.from,
                    to: testCase.to
                )
            }
        }
    }
    
    func testExchangeRate_RateCalculation_PerformsWell() {
        let exchangeManager = ExchangeRateManager.shared
        
        // Setup comprehensive exchange rates
        var rates: [String: Double] = [:]
        let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL"]
        
        for (i, from) in currencies.enumerated() {
            for (j, to) in currencies.enumerated() {
                if i != j {
                    rates["\(from)_\(to)"] = Double.random(in: 0.1...10.0)
                }
            }
        }
        
        exchangeManager.exchangeRates = rates
        
        // Test rate lookup performance
        measure {
            for _ in 0..<1000 {
                let from = currencies.randomElement()!
                let to = currencies.randomElement()!
                _ = exchangeManager.getExchangeRate(from: from, to: to)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsage_LargeDataSet_StaysWithinLimits() {
        // This test monitors memory usage during large operations
        let initialMemory = getMemoryUsage()
        
        // Create large dataset
        for i in 0..<10000 {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date().addingTimeInterval(TimeInterval(-i))
            entry.price = Double(i % 1000) + 0.99
            entry.currency = ["EUR", "USD", "GBP"][i % 3]
            entry.workMinutes = Double(i % 600) + 1.0
            entry.source = .manual
            
            // Add attachment to some entries
            if i % 10 == 0 {
                let image = createTestImage()
                try! entry.setAttachmentImage(image)
            }
        }
        
        try! testContext.save()
        
        let afterCreationMemory = getMemoryUsage()
        let memoryIncrease = afterCreationMemory - initialMemory
        
        // Memory increase should be reasonable (less than 100MB for 10k entries)
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024) // 100MB
        
        // Perform operations and check memory doesn't grow excessively
        let fetchRequest: NSFetchRequest = HistoryEntry.fetchRequest()
        fetchRequest.fetchLimit = 1000
        
        for _ in 0..<10 {
            _ = try! testContext.fetch(fetchRequest)
        }
        
        let finalMemory = getMemoryUsage()
        let totalIncrease = finalMemory - initialMemory
        
        // Total memory increase should still be reasonable
        XCTAssertLessThan(totalIncrease, 150 * 1024 * 1024) // 150MB
    }
    
    // MARK: - Concurrent Performance Tests
    
    func testConcurrentOperations_MultipleCalculations_PerformsWell() {
        let expectation = XCTestExpectation(description: "Concurrent calculations")
        expectation.expectedFulfillmentCount = 10
        
        let startTime = Date()
        
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                for j in 0..<100 {
                    _ = try! self.conversionEngine.calculateWorkTime(
                        price: Double(i * 100 + j) + 0.99,
                        currency: "EUR",
                        wageAmount: 25.0,
                        wageCurrency: "EUR",
                        wagePeriod: .hourly
                    )
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0) // Should complete in under 5 seconds
    }
    
    func testConcurrentOperations_FileAttachments_PerformsWell() {
        let expectation = XCTestExpectation(description: "Concurrent file operations")
        expectation.expectedFulfillmentCount = 5
        
        let startTime = Date()
        
        for _ in 0..<5 {
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<20 {
                    let image = self.createTestImage()
                    let id = UUID()
                    try! self.attachmentManager.saveAttachment(image, for: id)
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 10.0) // Should complete in under 10 seconds
    }
    
    // MARK: - Helper Methods
    
    /// Creates an in-memory Core Data stack using the real data model.
    ///
    /// The default implementation of this method in the original performance tests
    /// used an empty `NSManagedObjectModel`, which meant that no entities were
    /// available during the test runs.  This caused any operations on
    /// `HistoryEntry` or `TimeBudgetEntity` to crash.  To faithfully exercise
    /// the same Core Data stack used by the app, this implementation loads the
    /// merged model from the `HistoryStore` bundle and ensures that both
    /// `HistoryEntry` and `TimeBudgetEntity` are present.  It then creates an
    /// `NSPersistentStoreCoordinator` with an in-memory store and returns a
    /// main‑queue context.
    private func createTestContext() -> NSManagedObjectContext {
        // Load the actual Core Data model bundled with HistoryStore
        let historyBundle = Bundle(for: DataController.self)
        guard let model = NSManagedObjectModel.mergedModel(from: [historyBundle]) else {
            fatalError("Failed to load LifeMeterModel")
        }
        
        // Ensure HistoryEntry entity exists (older model versions may exclude it)
        if model.entitiesByName["HistoryEntry"] == nil {
            let entity = NSEntityDescription()
            entity.name = "HistoryEntry"
            entity.managedObjectClassName = "HistoryEntry"
            
            // Attributes
            let calculationId = NSAttributeDescription()
            calculationId.name = "calculationId"
            calculationId.attributeType = .UUIDAttributeType
            calculationId.isOptional = true
            
            let timestamp = NSAttributeDescription()
            timestamp.name = "timestamp"
            timestamp.attributeType = .dateAttributeType
            timestamp.isOptional = false
            
            let price = NSAttributeDescription()
            price.name = "price"
            price.attributeType = .doubleAttributeType
            price.defaultValue = 0.0
            
            let currency = NSAttributeDescription()
            currency.name = "currency"
            currency.attributeType = .stringAttributeType
            currency.isOptional = false
            
            let workMinutes = NSAttributeDescription()
            workMinutes.name = "workMinutes"
            workMinutes.attributeType = .doubleAttributeType
            workMinutes.defaultValue = 0.0
            
            let source = NSAttributeDescription()
            source.name = "source"
            source.attributeType = .stringAttributeType
            source.isOptional = true
            
            let photoData = NSAttributeDescription()
            photoData.name = "photoData"
            photoData.attributeType = .binaryDataAttributeType
            photoData.isOptional = true
            photoData.allowsExternalBinaryDataStorage = true
            
            let attachmentURL = NSAttributeDescription()
            attachmentURL.name = "attachmentURL"
            attachmentURL.attributeType = .URIAttributeType
            attachmentURL.isOptional = true
            
            entity.properties = [
                calculationId,
                timestamp,
                price,
                currency,
                workMinutes,
                source,
                photoData,
                attachmentURL
            ]
            
            model.entities.append(entity)
        }
        
        // Ensure TimeBudgetEntity is available for tests
        addTimeBudgetEntity(to: model)
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor.random.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func cleanupTestData() {
        // Clean up Core Data
        let fetchRequest: NSFetchRequest = HistoryEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? testContext.execute(deleteRequest)
        
        // Clean up file attachments
        try? attachmentManager.cleanupOrphanedAttachments(validCalculationIds: Set())
        
        // Clean up budgets
        let budgetStorage = TimeBudgetStorage.shared
        try? budgetStorage.saveBudgets([])
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info))/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
}

// MARK: - Extensions for Testing
extension UIColor {
    static var random: UIColor {
        return UIColor(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            alpha: 1.0
        )
    }
}

// MARK: - Mock Widget Snapshot Generator
class WidgetSnapshotGenerator {
    func generateSnapshot(for state: CatState, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let ctx = UIGraphicsGetCurrentContext()!
        
        // Simple colored rectangle based on cat state
        let color: UIColor
        switch state {
        case .sleeping:
            color = .blue
        case .resting:
            color = .green
        case .alert:
            color = .orange
        case .working:
            color = .red
        }
        
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}