import CloudKit
import CoreData
import Foundation
import os.log

// MARK: - Core Data Stack

@available(iOS 15.0, *)
public class DataController: ObservableObject {
    public static let shared = DataController()

    public let container: NSPersistentCloudKitContainer
    @Published public var migrationError: Error?

    private init() {
        container = NSPersistentCloudKitContainer(name: "LifeMeterModel")

        // Configure CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.lifemeter.app"
        )

        do {
            try loadStores(description: description)
        } catch {
            migrationError = error
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Persistent Store Loading

    private func loadStores(description: NSPersistentStoreDescription) throws {
        var loadError: Error?
        let group = DispatchGroup()
        group.enter()
        container.loadPersistentStores { _, error in
            loadError = error
            group.leave()
        }
        group.wait()

        if let error = loadError {
            moveCorruptedStore(originalURL: description.url)
            os_log(.fault, "Failed to load persistent store: %{public}@", error.localizedDescription)
            throw error
        }
    }

    private func moveCorruptedStore(originalURL: URL?) {
        guard let originalURL else { return }
        let fileManager = FileManager.default
        let supportDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LifeMeter/Corrupted", isDirectory: true)
        do {
            try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let destination = supportDir.appendingPathComponent(originalURL.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: originalURL, to: destination)
        } catch {
            os_log(.fault, "Failed to move corrupted store: %{public}@", error.localizedDescription)
        }
    }

    public func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                    os_log(.error, "Failed to save context: %{public}@", error.localizedDescription)
                #endif
            }
        }
    }
}

// MARK: - Calculation Entity

@objc(Calculation)
public class Calculation: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var price: Double
    @NSManaged public var minutes: Double
    @NSManaged public var currency: String
    @NSManaged public var imageData: Data?
    @NSManaged public var notes: String?

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        timestamp = Date()
    }
}

// MARK: - User Settings Entity

@objc(UserSettings)
public class UserSettings: NSManagedObject {
    @NSManaged public var hourlyWage: Double
    @NSManaged public var currency: String
    @NSManaged public var hasCompletedOnboarding: Bool
    @NSManaged public var cloudSyncEnabled: Bool
    @NSManaged public var lastModified: Date

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        lastModified = Date()
        hasCompletedOnboarding = false
        cloudSyncEnabled = true
        currency = Locale.current.currency?.identifier ?? "EUR"
    }
}

// MARK: - Core Data Extensions

public extension Calculation {
    internal static func fetchRequest() -> NSFetchRequest<Calculation> {
        return NSFetchRequest<Calculation>(entityName: "Calculation")
    }

    static func allCalculations() -> NSFetchRequest<Calculation> {
        let request: NSFetchRequest<Calculation> = Calculation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Calculation.timestamp, ascending: false)]
        return request
    }

    static func recentCalculations(limit: Int = 10) -> NSFetchRequest<Calculation> {
        let request = allCalculations()
        request.fetchLimit = limit
        return request
    }
}

extension UserSettings {
    static func fetchRequest() -> NSFetchRequest<UserSettings> {
        return NSFetchRequest<UserSettings>(entityName: "UserSettings")
    }

    public static func current() -> NSFetchRequest<UserSettings> {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.fetchLimit = 1
        return request
    }
}
