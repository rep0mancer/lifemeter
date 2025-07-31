import CoreData

// swiftlint:disable force_unwrapping
import Foundation
import UIKit
import os.log

// MARK: - File-Based Attachment Manager

public class FileBasedAttachmentManager {
    // MARK: - Singleton

    public static let shared = FileBasedAttachmentManager()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let attachmentsDirectory: URL

    // MARK: - Initialization

    private init() {
        // Create attachments directory in Documents
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate documents directory")
        }
        attachmentsDirectory = documentsDirectory.appendingPathComponent("Attachments", isDirectory: true)

        createAttachmentsDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    /// Save image attachment and return file URL
    public func saveAttachment(_ image: UIImage, for calculationId: UUID) throws -> URL {
        let filename = "\(calculationId.uuidString).jpg"
        let fileURL = attachmentsDirectory.appendingPathComponent(filename)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AttachmentError.imageCompressionFailed
        }

        try imageData.write(to: fileURL)
        return fileURL
    }

    /// Load image attachment from file URL
    public func loadAttachment(from fileURL: URL) -> UIImage? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Delete attachment file
    public func deleteAttachment(at fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // File doesn't exist, nothing to delete
        }

        try fileManager.removeItem(at: fileURL)
    }

    /// Get file size of attachment
    public func getAttachmentSize(at fileURL: URL) -> Int64? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    /// Check if attachment exists
    public func attachmentExists(at fileURL: URL) -> Bool {
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Get total size of all attachments
    public func getTotalAttachmentsSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: attachmentsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                continue
            }
        }

        return totalSize
    }

    /// Clean up orphaned attachments (files without corresponding database entries)
    public func cleanupOrphanedAttachments(validCalculationIds: Set<UUID>) throws {
        guard let enumerator = fileManager.enumerator(at: attachmentsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        var orphanedFiles: [URL] = []

        for case let fileURL as URL in enumerator {
            let filename = fileURL.lastPathComponent

            // Extract UUID from filename (format: "UUID.jpg")
            if let uuidString = filename.components(separatedBy: ".").first,
               let uuid = UUID(uuidString: uuidString)
            {
                if !validCalculationIds.contains(uuid) {
                    orphanedFiles.append(fileURL)
                }
            } else {
                // Invalid filename format, consider orphaned
                orphanedFiles.append(fileURL)
            }
        }

        // Delete orphaned files
        for fileURL in orphanedFiles {
            try fileManager.removeItem(at: fileURL)
        }
    }

    /// Migrate existing binary data to file-based storage
    public func migrateBinaryDataToFiles(context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "photoData != nil AND attachmentURL == nil")

        let entries = try context.fetch(request)

        for entry in entries {
            guard let photoData = entry.photoData,
                  let image = UIImage(data: photoData),
                  let calculationId = entry.calculationId
            else {
                continue
            }

            do {
                let fileURL = try saveAttachment(image, for: calculationId)
                entry.attachmentURL = fileURL
                entry.photoData = nil // Remove binary data
            } catch {
                #if DEBUG
                    os_log(
                        .error,
                        "Failed to migrate attachment for entry %{private}@: %{private}@",
                        calculationId.uuidString,
                        String(describing: error)
                    )
                #endif
            }
        }

        try context.save()
    }

    // MARK: - Private Methods

    private func createAttachmentsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: attachmentsDirectory.path) {
            do {
                try fileManager.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)
            } catch {
                #if DEBUG
                    os_log(
                        .error,
                        "Failed to create attachments directory: %{private}@",
                        String(describing: error)
                    )
                #endif
            }
        }
    }
}

// MARK: - Attachment Error

public enum AttachmentError: LocalizedError {
    case imageCompressionFailed
    case fileNotFound
    case saveFailed(Error)
    case deleteFailed(Error)
    case migrationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image for storage"
        case .fileNotFound:
            return "Attachment file not found"
        case let .saveFailed(error):
            return "Failed to save attachment: \(error.localizedDescription)"
        case let .deleteFailed(error):
            return "Failed to delete attachment: \(error.localizedDescription)"
        case let .migrationFailed(error):
            return "Failed to migrate attachment: \(error.localizedDescription)"
        }
    }
}

// MARK: - Enhanced History Entry

public extension HistoryEntry {
    /// Get attachment image (loads from file if needed)
    var attachmentImage: UIImage? {
        // First try to load from file URL
        if let attachmentURL = attachmentURL {
            return FileBasedAttachmentManager.shared.loadAttachment(from: attachmentURL)
        }

        // Fallback to legacy binary data
        if let photoData = photoData {
            return UIImage(data: photoData)
        }

        return nil
    }

    /// Set attachment image (saves to file)
    func setAttachmentImage(_ image: UIImage) throws {
        guard let calculationId = calculationId else {
            throw AttachmentError.saveFailed(NSError(domain: "HistoryEntry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing calculation ID"]))
        }

        do {
            let fileURL = try FileBasedAttachmentManager.shared.saveAttachment(image, for: calculationId)
            attachmentURL = fileURL
            photoData = nil // Clear legacy binary data
        } catch {
            throw AttachmentError.saveFailed(error)
        }
    }

    /// Remove attachment
    func removeAttachment() throws {
        if let attachmentURL = attachmentURL {
            try FileBasedAttachmentManager.shared.deleteAttachment(at: attachmentURL)
            self.attachmentURL = nil
        }

        photoData = nil
    }

    /// Check if entry has attachment
    var hasAttachment: Bool {
        if let attachmentURL = attachmentURL {
            return FileBasedAttachmentManager.shared.attachmentExists(at: attachmentURL)
        }

        return photoData != nil
    }

    /// Get attachment file size
    var attachmentSize: Int64? {
        if let attachmentURL = attachmentURL {
            return FileBasedAttachmentManager.shared.getAttachmentSize(at: attachmentURL)
        }

        if let photoData = photoData {
            return Int64(photoData.count)
        }

        return nil
    }
}

// MARK: - Core Data Migration Helper

public class AttachmentMigrationHelper {
    /// Perform migration from binary data to file-based storage
    public static func performMigration(context: NSManagedObjectContext) throws {
        #if DEBUG
            os_log(
                .info,
                "Starting attachment migration..."
            )
        #endif

        let startTime = Date()

        do {
            try FileBasedAttachmentManager.shared.migrateBinaryDataToFiles(context: context)

            let duration = Date().timeIntervalSince(startTime)
            #if DEBUG
                os_log(
                    .info,
                    "Attachment migration completed in %{public}.2f seconds",
                    duration
                )
            #endif

        } catch {
            #if DEBUG
                os_log(
                    .error,
                    "Attachment migration failed: %{private}@",
                    String(describing: error)
                )
            #endif
            throw AttachmentError.migrationFailed(error)
        }
    }

    /// Validate migration results
    public static func validateMigration(context: NSManagedObjectContext) throws -> MigrationValidationResult {
        let request: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        let allEntries = try context.fetch(request)

        var result = MigrationValidationResult()

        for entry in allEntries {
            if entry.photoData != nil && entry.attachmentURL != nil {
                result.entriesWithBothFormats += 1
            } else if entry.photoData != nil {
                result.entriesWithBinaryData += 1
            } else if let attachmentURL = entry.attachmentURL {
                result.entriesWithFileAttachments += 1

                // Validate file exists
                if FileBasedAttachmentManager.shared.attachmentExists(at: attachmentURL) {
                    result.validFileAttachments += 1
                } else {
                    result.invalidFileAttachments += 1
                }
            } else {
                result.entriesWithoutAttachments += 1
            }
        }

        result.totalEntries = allEntries.count
        return result
    }

    /// Clean up after successful migration
    public static func cleanupAfterMigration(context: NSManagedObjectContext) throws {
        // Get all valid calculation IDs
        let request: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        let entries = try context.fetch(request)
        let validIds = Set(entries.compactMap { $0.calculationId })

        // Clean up orphaned files
        try FileBasedAttachmentManager.shared.cleanupOrphanedAttachments(validCalculationIds: validIds)
    }
}

// MARK: - Migration Validation Result

public struct MigrationValidationResult {
    public var totalEntries: Int = 0
    public var entriesWithBinaryData: Int = 0
    public var entriesWithFileAttachments: Int = 0
    public var entriesWithBothFormats: Int = 0
    public var entriesWithoutAttachments: Int = 0
    public var validFileAttachments: Int = 0
    public var invalidFileAttachments: Int = 0

    public var migrationSuccessRate: Double {
        guard totalEntries > 0 else { return 1.0 }
        return Double(entriesWithFileAttachments) / Double(totalEntries)
    }

    public var fileValidationRate: Double {
        guard entriesWithFileAttachments > 0 else { return 1.0 }
        return Double(validFileAttachments) / Double(entriesWithFileAttachments)
    }

    public var isFullyMigrated: Bool {
        return entriesWithBinaryData == 0 && invalidFileAttachments == 0
    }
}

// MARK: - Attachment Statistics

public struct AttachmentStatistics {
    public let totalAttachments: Int
    public let totalSize: Int64
    public let averageSize: Int64
    public let largestAttachment: Int64
    public let oldestAttachment: Date?
    public let newestAttachment: Date?

    public var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedAverageSize: String {
        return ByteCountFormatter.string(fromByteCount: averageSize, countStyle: .file)
    }
}

// MARK: - Attachment Statistics Provider

public extension FileBasedAttachmentManager {
    /// Get comprehensive attachment statistics
    func getAttachmentStatistics() -> AttachmentStatistics {
        guard let enumerator = fileManager.enumerator(at: attachmentsDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return AttachmentStatistics(totalAttachments: 0, totalSize: 0, averageSize: 0, largestAttachment: 0, oldestAttachment: nil, newestAttachment: nil)
        }

        var totalSize: Int64 = 0
        var largestSize: Int64 = 0
        var attachmentCount = 0
        var oldestDate: Date?
        var newestDate: Date?

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])

                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                    largestSize = max(largestSize, Int64(fileSize))
                    attachmentCount += 1
                }

                if let creationDate = resourceValues.creationDate {
                    if let currentOldest = oldestDate {
                        if creationDate < currentOldest {
                            oldestDate = creationDate
                        }
                    } else {
                        oldestDate = creationDate
                    }
                    if let currentNewest = newestDate {
                        if creationDate > currentNewest {
                            newestDate = creationDate
                        }
                    } else {
                        newestDate = creationDate
                    }
                }
            } catch {
                continue
            }
        }

        let averageSize = attachmentCount > 0 ? totalSize / Int64(attachmentCount) : 0

        return AttachmentStatistics(
            totalAttachments: attachmentCount,
            totalSize: totalSize,
            averageSize: averageSize,
            largestAttachment: largestSize,
            oldestAttachment: oldestDate,
            newestAttachment: newestDate
        )
    }
}
