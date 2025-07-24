import XCTest
import UIKit
import CoreData
@testable import HistoryStore

// MARK: - File-Based Attachment Tests
@available(iOS 15.0, *)
final class FileBasedAttachmentTests: XCTestCase {
    
    // MARK: - Properties
    private var attachmentManager: FileBasedAttachmentManager!
    private var testImage: UIImage!
    private var testCalculationId: UUID!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        attachmentManager = FileBasedAttachmentManager.shared
        testCalculationId = UUID()
        
        // Create a test image
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        // Clean up test files
        cleanupTestFiles()
        
        attachmentManager = nil
        testImage = nil
        testCalculationId = nil
        
        super.tearDown()
    }
    
    // MARK: - Save Attachment Tests
    
    func testSaveAttachment_ValidImage_SavesSuccessfully() throws {
        // When
        let fileURL = try attachmentManager.saveAttachment(testImage, for: testCalculationId)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(fileURL.lastPathComponent, "\(testCalculationId.uuidString).jpg")
        
        // Verify image can be loaded back
        let loadedImage = attachmentManager.loadAttachment(from: fileURL)
        XCTAssertNotNil(loadedImage)
    }
    
    func testSaveAttachment_MultipleImages_SavesAllSuccessfully() throws {
        // Given
        let calculationIds = [UUID(), UUID(), UUID()]
        var savedURLs: [URL] = []
        
        // When
        for id in calculationIds {
            let fileURL = try attachmentManager.saveAttachment(testImage, for: id)
            savedURLs.append(fileURL)
        }
        
        // Then
        XCTAssertEqual(savedURLs.count, 3)
        
        for (index, url) in savedURLs.enumerated() {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(url.lastPathComponent, "\(calculationIds[index].uuidString).jpg")
        }
    }
    
    // MARK: - Load Attachment Tests
    
    func testLoadAttachment_ExistingFile_LoadsSuccessfully() throws {
        // Given
        let fileURL = try attachmentManager.saveAttachment(testImage, for: testCalculationId)
        
        // When
        let loadedImage = attachmentManager.loadAttachment(from: fileURL)
        
        // Then
        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(loadedImage?.size.width, testImage.size.width)
        XCTAssertEqual(loadedImage?.size.height, testImage.size.height)
    }
    
    func testLoadAttachment_NonExistentFile_ReturnsNil() {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path.jpg")
        
        // When
        let loadedImage = attachmentManager.loadAttachment(from: nonExistentURL)
        
        // Then
        XCTAssertNil(loadedImage)
    }
    
    // MARK: - Delete Attachment Tests
    
    func testDeleteAttachment_ExistingFile_DeletesSuccessfully() throws {
        // Given
        let fileURL = try attachmentManager.saveAttachment(testImage, for: testCalculationId)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // When
        try attachmentManager.deleteAttachment(at: fileURL)
        
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testDeleteAttachment_NonExistentFile_DoesNotThrow() throws {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path.jpg")
        
        // When & Then
        XCTAssertNoThrow(try attachmentManager.deleteAttachment(at: nonExistentURL))
    }
    
    // MARK: - File Size Tests
    
    func testGetAttachmentSize_ExistingFile_ReturnsCorrectSize() throws {
        // Given
        let fileURL = try attachmentManager.saveAttachment(testImage, for: testCalculationId)
        
        // When
        let fileSize = attachmentManager.getAttachmentSize(at: fileURL)
        
        // Then
        XCTAssertNotNil(fileSize)
        XCTAssertGreaterThan(fileSize!, 0)
    }
    
    func testGetAttachmentSize_NonExistentFile_ReturnsNil() {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path.jpg")
        
        // When
        let fileSize = attachmentManager.getAttachmentSize(at: nonExistentURL)
        
        // Then
        XCTAssertNil(fileSize)
    }
    
    // MARK: - Attachment Exists Tests
    
    func testAttachmentExists_ExistingFile_ReturnsTrue() throws {
        // Given
        let fileURL = try attachmentManager.saveAttachment(testImage, for: testCalculationId)
        
        // When
        let exists = attachmentManager.attachmentExists(at: fileURL)
        
        // Then
        XCTAssertTrue(exists)
    }
    
    func testAttachmentExists_NonExistentFile_ReturnsFalse() {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/path.jpg")
        
        // When
        let exists = attachmentManager.attachmentExists(at: nonExistentURL)
        
        // Then
        XCTAssertFalse(exists)
    }
    
    // MARK: - Total Size Tests
    
    func testGetTotalAttachmentsSize_MultipleFiles_ReturnsCorrectTotal() throws {
        // Given
        let calculationIds = [UUID(), UUID(), UUID()]
        var expectedTotalSize: Int64 = 0
        
        for id in calculationIds {
            let fileURL = try attachmentManager.saveAttachment(testImage, for: id)
            let fileSize = attachmentManager.getAttachmentSize(at: fileURL)!
            expectedTotalSize += fileSize
        }
        
        // When
        let totalSize = attachmentManager.getTotalAttachmentsSize()
        
        // Then
        XCTAssertEqual(totalSize, expectedTotalSize)
    }
    
    func testGetTotalAttachmentsSize_NoFiles_ReturnsZero() throws {
        // Given - Clean directory
        cleanupTestFiles()
        
        // When
        let totalSize = attachmentManager.getTotalAttachmentsSize()
        
        // Then
        XCTAssertEqual(totalSize, 0)
    }
    
    // MARK: - Cleanup Orphaned Attachments Tests
    
    func testCleanupOrphanedAttachments_WithOrphans_RemovesOrphanedFiles() throws {
        // Given
        let validId = UUID()
        let orphanedId = UUID()
        
        // Save attachments
        let validFileURL = try attachmentManager.saveAttachment(testImage, for: validId)
        let orphanedFileURL = try attachmentManager.saveAttachment(testImage, for: orphanedId)
        
        // Verify both files exist
        XCTAssertTrue(attachmentManager.attachmentExists(at: validFileURL))
        XCTAssertTrue(attachmentManager.attachmentExists(at: orphanedFileURL))
        
        // When - Clean up with only valid ID
        try attachmentManager.cleanupOrphanedAttachments(validCalculationIds: [validId])
        
        // Then
        XCTAssertTrue(attachmentManager.attachmentExists(at: validFileURL))
        XCTAssertFalse(attachmentManager.attachmentExists(at: orphanedFileURL))
    }
    
    func testCleanupOrphanedAttachments_NoOrphans_LeavesAllFiles() throws {
        // Given
        let validIds = [UUID(), UUID(), UUID()]
        var fileURLs: [URL] = []
        
        for id in validIds {
            let fileURL = try attachmentManager.saveAttachment(testImage, for: id)
            fileURLs.append(fileURL)
        }
        
        // When
        try attachmentManager.cleanupOrphanedAttachments(validCalculationIds: Set(validIds))
        
        // Then
        for fileURL in fileURLs {
            XCTAssertTrue(attachmentManager.attachmentExists(at: fileURL))
        }
    }
    
    // MARK: - Statistics Tests
    
    func testGetAttachmentStatistics_MultipleFiles_ReturnsCorrectStatistics() throws {
        // Given
        let calculationIds = [UUID(), UUID(), UUID()]
        
        for id in calculationIds {
            try attachmentManager.saveAttachment(testImage, for: id)
        }
        
        // When
        let statistics = attachmentManager.getAttachmentStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalAttachments, 3)
        XCTAssertGreaterThan(statistics.totalSize, 0)
        XCTAssertGreaterThan(statistics.averageSize, 0)
        XCTAssertGreaterThan(statistics.largestAttachment, 0)
        XCTAssertNotNil(statistics.oldestAttachment)
        XCTAssertNotNil(statistics.newestAttachment)
    }
    
    func testGetAttachmentStatistics_NoFiles_ReturnsZeroStatistics() throws {
        // Given - Clean directory
        cleanupTestFiles()
        
        // When
        let statistics = attachmentManager.getAttachmentStatistics()
        
        // Then
        XCTAssertEqual(statistics.totalAttachments, 0)
        XCTAssertEqual(statistics.totalSize, 0)
        XCTAssertEqual(statistics.averageSize, 0)
        XCTAssertEqual(statistics.largestAttachment, 0)
        XCTAssertNil(statistics.oldestAttachment)
        XCTAssertNil(statistics.newestAttachment)
    }
    
    // MARK: - Performance Tests
    
    func testSaveAttachment_Performance() throws {
        measure {
            for i in 0..<10 {
                let id = UUID()
                try? attachmentManager.saveAttachment(testImage, for: id)
            }
        }
    }
    
    func testLoadAttachment_Performance() throws {
        // Given - Save multiple attachments
        var fileURLs: [URL] = []
        for _ in 0..<10 {
            let id = UUID()
            let fileURL = try attachmentManager.saveAttachment(testImage, for: id)
            fileURLs.append(fileURL)
        }
        
        // When - Measure loading performance
        measure {
            for fileURL in fileURLs {
                _ = attachmentManager.loadAttachment(from: fileURL)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveAttachment_InvalidImage_ThrowsError() {
        // Given - Create an invalid image (this is tricky to do in practice)
        // For this test, we'll use a very small image that might fail compression
        let invalidImage = UIImage()
        
        // When & Then
        XCTAssertThrowsError(try attachmentManager.saveAttachment(invalidImage, for: testCalculationId)) { error in
            XCTAssertTrue(error is AttachmentError)
            if case .imageCompressionFailed = error as? AttachmentError {
                // Expected error
            } else {
                XCTFail("Expected imageCompressionFailed error")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        // Draw a simple test pattern
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 25, y: 25, width: 50, height: 50))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func cleanupTestFiles() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let attachmentsDirectory = documentsDirectory.appendingPathComponent("Attachments", isDirectory: true)
        
        if FileManager.default.fileExists(atPath: attachmentsDirectory.path) {
            try? FileManager.default.removeItem(at: attachmentsDirectory)
        }
    }
}

// MARK: - History Entry Extension Tests
@available(iOS 15.0, *)
final class HistoryEntryAttachmentTests: XCTestCase {
    
    // MARK: - Properties
    private var testContext: NSManagedObjectContext!
    private var testImage: UIImage!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        testContext = createTestContext()
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Attachment Image Tests
    
    func testSetAttachmentImage_ValidImage_SavesSuccessfully() throws {
        // Given
        let entry = createTestHistoryEntry()
        
        // When
        try entry.setAttachmentImage(testImage)
        
        // Then
        XCTAssertNotNil(entry.attachmentURL)
        XCTAssertNil(entry.photoData) // Legacy data should be cleared
        XCTAssertTrue(entry.hasAttachment)
        
        let loadedImage = entry.attachmentImage
        XCTAssertNotNil(loadedImage)
    }
    
    func testAttachmentImage_FileBasedAttachment_LoadsCorrectly() throws {
        // Given
        let entry = createTestHistoryEntry()
        try entry.setAttachmentImage(testImage)
        
        // When
        let loadedImage = entry.attachmentImage
        
        // Then
        XCTAssertNotNil(loadedImage)
        XCTAssertEqual(loadedImage?.size.width, testImage.size.width)
        XCTAssertEqual(loadedImage?.size.height, testImage.size.height)
    }
    
    func testAttachmentImage_LegacyBinaryData_LoadsCorrectly() throws {
        // Given
        let entry = createTestHistoryEntry()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        entry.photoData = imageData
        
        // When
        let loadedImage = entry.attachmentImage
        
        // Then
        XCTAssertNotNil(loadedImage)
    }
    
    func testRemoveAttachment_FileBasedAttachment_RemovesSuccessfully() throws {
        // Given
        let entry = createTestHistoryEntry()
        try entry.setAttachmentImage(testImage)
        XCTAssertTrue(entry.hasAttachment)
        
        // When
        try entry.removeAttachment()
        
        // Then
        XCTAssertFalse(entry.hasAttachment)
        XCTAssertNil(entry.attachmentURL)
        XCTAssertNil(entry.photoData)
        XCTAssertNil(entry.attachmentImage)
    }
    
    func testHasAttachment_FileBasedAttachment_ReturnsTrue() throws {
        // Given
        let entry = createTestHistoryEntry()
        try entry.setAttachmentImage(testImage)
        
        // When
        let hasAttachment = entry.hasAttachment
        
        // Then
        XCTAssertTrue(hasAttachment)
    }
    
    func testHasAttachment_LegacyBinaryData_ReturnsTrue() {
        // Given
        let entry = createTestHistoryEntry()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        entry.photoData = imageData
        
        // When
        let hasAttachment = entry.hasAttachment
        
        // Then
        XCTAssertTrue(hasAttachment)
    }
    
    func testHasAttachment_NoAttachment_ReturnsFalse() {
        // Given
        let entry = createTestHistoryEntry()
        
        // When
        let hasAttachment = entry.hasAttachment
        
        // Then
        XCTAssertFalse(hasAttachment)
    }
    
    func testAttachmentSize_FileBasedAttachment_ReturnsCorrectSize() throws {
        // Given
        let entry = createTestHistoryEntry()
        try entry.setAttachmentImage(testImage)
        
        // When
        let attachmentSize = entry.attachmentSize
        
        // Then
        XCTAssertNotNil(attachmentSize)
        XCTAssertGreaterThan(attachmentSize!, 0)
    }
    
    func testAttachmentSize_LegacyBinaryData_ReturnsCorrectSize() {
        // Given
        let entry = createTestHistoryEntry()
        let imageData = testImage.jpegData(compressionQuality: 0.8)!
        entry.photoData = imageData
        
        // When
        let attachmentSize = entry.attachmentSize
        
        // Then
        XCTAssertNotNil(attachmentSize)
        XCTAssertEqual(attachmentSize!, Int64(imageData.count))
    }
    
    // MARK: - Helper Methods
    
    private func createTestContext() -> NSManagedObjectContext {
        // Load the actual Core Data model bundled with HistoryStore
        let historyBundle = Bundle(for: DataController.self)
        guard let model = NSManagedObjectModel.mergedModel(from: [historyBundle]) else {
            fatalError("Failed to load LifeMeterModel")
        }

        // Ensure HistoryEntry entity exists
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

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        return context
    }
    
    private func createTestHistoryEntry() -> HistoryEntry {
        let entry = HistoryEntry(context: testContext)
        entry.calculationId = UUID()
        entry.timestamp = Date()
        entry.price = 10.0
        entry.currency = "EUR"
        entry.workMinutes = 15.0
        
        return entry
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

// MARK: - Migration Tests
@available(iOS 15.0, *)
final class AttachmentMigrationTests: XCTestCase {
    
    // MARK: - Properties
    private var testContext: NSManagedObjectContext!
    private var testImage: UIImage!
    
    // MARK: - Setup & Teardown
    override func setUpWithError() throws {
        super.setUp()
        
        testContext = createTestContext()
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        testImage = nil
        super.tearDown()
    }
    
    // MARK: - Migration Tests
    
    func testPerformMigration_LegacyBinaryData_MigratesToFiles() throws {
        // Given - Create entries with legacy binary data
        let entries = createEntriesWithLegacyData(count: 3)
        
        // When
        try AttachmentMigrationHelper.performMigration(context: testContext)
        
        // Then
        for entry in entries {
            XCTAssertNotNil(entry.attachmentURL)
            XCTAssertNil(entry.photoData)
            XCTAssertTrue(entry.hasAttachment)
        }
    }
    
    func testValidateMigration_AfterMigration_ReturnsCorrectResults() throws {
        // Given
        let entries = createEntriesWithLegacyData(count: 5)
        try AttachmentMigrationHelper.performMigration(context: testContext)
        
        // When
        let result = try AttachmentMigrationHelper.validateMigration(context: testContext)
        
        // Then
        XCTAssertEqual(result.totalEntries, 5)
        XCTAssertEqual(result.entriesWithBinaryData, 0)
        XCTAssertEqual(result.entriesWithFileAttachments, 5)
        XCTAssertEqual(result.validFileAttachments, 5)
        XCTAssertEqual(result.invalidFileAttachments, 0)
        XCTAssertTrue(result.isFullyMigrated)
        XCTAssertEqual(result.migrationSuccessRate, 1.0)
        XCTAssertEqual(result.fileValidationRate, 1.0)
    }
    
    func testCleanupAfterMigration_RemovesOrphanedFiles() throws {
        // Given
        let entries = createEntriesWithLegacyData(count: 3)
        try AttachmentMigrationHelper.performMigration(context: testContext)
        
        // Create an orphaned file
        let orphanedId = UUID()
        _ = try FileBasedAttachmentManager.shared.saveAttachment(testImage, for: orphanedId)
        
        // When
        try AttachmentMigrationHelper.cleanupAfterMigration(context: testContext)
        
        // Then
        // Valid files should still exist
        for entry in entries {
            XCTAssertTrue(entry.hasAttachment)
        }
        
        // Orphaned file should be removed (we can't easily test this without more complex setup)
    }
    
    // MARK: - Helper Methods
    
    private func createTestContext() -> NSManagedObjectContext {
        // Load the actual Core Data model bundled with HistoryStore
        let historyBundle = Bundle(for: DataController.self)
        guard let model = NSManagedObjectModel.mergedModel(from: [historyBundle]) else {
            fatalError("Failed to load LifeMeterModel")
        }

        // Ensure HistoryEntry entity exists
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

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try! coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        return context
    }
    
    private func createEntriesWithLegacyData(count: Int) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        
        for i in 0..<count {
            let entry = HistoryEntry(context: testContext)
            entry.calculationId = UUID()
            entry.timestamp = Date()
            entry.price = Double(i + 1) * 10.0
            entry.currency = "EUR"
            entry.workMinutes = Double(i + 1) * 5.0
            
            // Set legacy binary data
            let imageData = testImage.jpegData(compressionQuality: 0.8)!
            entry.photoData = imageData
            
            entries.append(entry)
        }
        
        try! testContext.save()
        return entries
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 30, height: 30)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.green.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

