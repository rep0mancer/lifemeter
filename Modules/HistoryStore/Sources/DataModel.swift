import Foundation
import CoreData
import CloudKit

// MARK: - Core Data Stack
@available(iOS 15.0, *)
public class DataController: ObservableObject {
    public static let shared = DataController()
    
    public let container: NSPersistentCloudKitContainer
    
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
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    public func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
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
    
    public override func awakeFromInsert() {
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
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        lastModified = Date()
        hasCompletedOnboarding = false
        cloudSyncEnabled = true
        currency = Locale.current.currency?.identifier ?? "EUR"
    }
}

// MARK: - Core Data Extensions
extension Calculation {
    static func fetchRequest() -> NSFetchRequest<Calculation> {
        return NSFetchRequest<Calculation>(entityName: "Calculation")
    }
    
    public static func allCalculations() -> NSFetchRequest<Calculation> {
        let request: NSFetchRequest<Calculation> = Calculation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Calculation.timestamp, ascending: false)]
        return request
    }
    
    public static func recentCalculations(limit: Int = 10) -> NSFetchRequest<Calculation> {
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

