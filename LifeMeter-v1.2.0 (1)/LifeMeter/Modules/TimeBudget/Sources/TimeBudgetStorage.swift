import Foundation
import CoreData

// MARK: - Time Budget Storage
public class TimeBudgetStorage {
    
    // MARK: - Singleton
    public static let shared = TimeBudgetStorage()
    
    // MARK: - Properties
    private let context: NSManagedObjectContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    private init() {
        // Use the same Core Data stack as HistoryStore
        self.context = PersistentContainer.shared.viewContext
        
        // Configure JSON coders
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// Save budgets to Core Data
    public func saveBudgets(_ budgets: [TimeBudget]) throws {
        // Clear existing budgets
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TimeBudgetEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try context.execute(deleteRequest)
        
        // Save new budgets
        for budget in budgets {
            let entity = TimeBudgetEntity(context: context)
            entity.id = budget.id
            entity.name = budget.name
            entity.totalWorkMinutes = budget.totalWorkMinutes
            entity.period = budget.period.rawValue
            entity.createdAt = budget.createdAt
            entity.periodStartDate = budget.periodStartDate
            
            // Encode categories and spending as JSON
            entity.categoriesData = try encoder.encode(budget.categories)
            entity.spendingData = try encoder.encode(budget.spending)
        }
        
        try context.save()
    }
    
    /// Load budgets from Core Data
    public func loadBudgets() throws -> [TimeBudget] {
        let fetchRequest: NSFetchRequest<TimeBudgetEntity> = TimeBudgetEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TimeBudgetEntity.createdAt, ascending: false)]
        
        let entities = try context.fetch(fetchRequest)
        
        return try entities.compactMap { entity in
            try convertEntityToBudget(entity)
        }
    }
    
    /// Save a single budget
    public func saveBudget(_ budget: TimeBudget) throws {
        let fetchRequest: NSFetchRequest<TimeBudgetEntity> = TimeBudgetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", budget.id as CVarArg)
        
        let entities = try context.fetch(fetchRequest)
        let entity = entities.first ?? TimeBudgetEntity(context: context)
        
        entity.id = budget.id
        entity.name = budget.name
        entity.totalWorkMinutes = budget.totalWorkMinutes
        entity.period = budget.period.rawValue
        entity.createdAt = budget.createdAt
        entity.periodStartDate = budget.periodStartDate
        entity.categoriesData = try encoder.encode(budget.categories)
        entity.spendingData = try encoder.encode(budget.spending)
        
        try context.save()
    }
    
    /// Delete a budget
    public func deleteBudget(withId id: UUID) throws {
        let fetchRequest: NSFetchRequest<TimeBudgetEntity> = TimeBudgetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let entities = try context.fetch(fetchRequest)
        
        for entity in entities {
            context.delete(entity)
        }
        
        try context.save()
    }
    
    /// Get budget statistics
    public func getBudgetStatistics() throws -> BudgetStatistics {
        let fetchRequest: NSFetchRequest<TimeBudgetEntity> = TimeBudgetEntity.fetchRequest()
        let entities = try context.fetch(fetchRequest)
        
        let budgets = try entities.compactMap { try convertEntityToBudget($0) }
        
        let totalBudgets = budgets.count
        let activeBudgets = budgets.filter { $0.isCurrentPeriod }.count
        let totalSpending = budgets.flatMap { $0.spending }.count
        
        let totalAllocatedTime = budgets.reduce(0) { $0 + $1.totalWorkMinutes }
        let totalUsedTime = budgets.reduce(0) { budget, total in
            total + budget.spending.reduce(0) { $0 + $1.workMinutes }
        }
        
        return BudgetStatistics(
            totalBudgets: totalBudgets,
            activeBudgets: activeBudgets,
            totalSpendingEntries: totalSpending,
            totalAllocatedMinutes: totalAllocatedTime,
            totalUsedMinutes: totalUsedTime,
            averageBudgetSize: totalBudgets > 0 ? totalAllocatedTime / Double(totalBudgets) : 0
        )
    }
    
    /// Clean up old budget data
    public func cleanupOldBudgets(olderThan date: Date) throws {
        let fetchRequest: NSFetchRequest<TimeBudgetEntity> = TimeBudgetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "createdAt < %@", date as NSDate)
        
        let entities = try context.fetch(fetchRequest)
        
        for entity in entities {
            context.delete(entity)
        }
        
        try context.save()
    }
    
    /// Export budgets to JSON
    public func exportBudgets() throws -> Data {
        let budgets = try loadBudgets()
        return try encoder.encode(budgets)
    }
    
    /// Import budgets from JSON
    public func importBudgets(from data: Data, replaceExisting: Bool = false) throws {
        let importedBudgets = try decoder.decode([TimeBudget].self, from: data)
        
        if replaceExisting {
            // Clear existing budgets
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TimeBudgetEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }
        
        // Save imported budgets
        try saveBudgets(importedBudgets)
    }
    
    // MARK: - Private Methods
    
    private func convertEntityToBudget(_ entity: TimeBudgetEntity) throws -> TimeBudget? {
        guard let id = entity.id,
              let name = entity.name,
              let periodString = entity.period,
              let period = BudgetPeriod(rawValue: periodString),
              let createdAt = entity.createdAt,
              let periodStartDate = entity.periodStartDate,
              let categoriesData = entity.categoriesData,
              let spendingData = entity.spendingData else {
            return nil
        }
        
        let categories = try decoder.decode([BudgetCategory].self, from: categoriesData)
        let spending = try decoder.decode([BudgetSpending].self, from: spendingData)
        
        var budget = TimeBudget(
            name: name,
            totalWorkMinutes: entity.totalWorkMinutes,
            period: period,
            categories: categories
        )
        
        // Set the stored values
        budget.spending = spending
        budget.periodStartDate = periodStartDate
        
        return budget
    }
}

// MARK: - Budget Statistics
public struct BudgetStatistics {
    public let totalBudgets: Int
    public let activeBudgets: Int
    public let totalSpendingEntries: Int
    public let totalAllocatedMinutes: Double
    public let totalUsedMinutes: Double
    public let averageBudgetSize: Double
    
    public var utilizationRate: Double {
        return totalAllocatedMinutes > 0 ? totalUsedMinutes / totalAllocatedMinutes : 0
    }
    
    public var formattedTotalAllocated: String {
        return TimeFormatter.formatMinutes(totalAllocatedMinutes)
    }
    
    public var formattedTotalUsed: String {
        return TimeFormatter.formatMinutes(totalUsedMinutes)
    }
    
    public var formattedAverageSize: String {
        return TimeFormatter.formatMinutes(averageBudgetSize)
    }
}

// MARK: - Core Data Entity Extension
@objc(TimeBudgetEntity)
public class TimeBudgetEntity: NSManagedObject {
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var totalWorkMinutes: Double
    @NSManaged public var period: String?
    @NSManaged public var categoriesData: Data?
    @NSManaged public var spendingData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var periodStartDate: Date?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TimeBudgetEntity> {
        return NSFetchRequest<TimeBudgetEntity>(entityName: "TimeBudgetEntity")
    }
}

// MARK: - Persistent Container Extension
extension PersistentContainer {
    
    /// Add TimeBudget entity to the Core Data model
    static func addTimeBudgetEntity(to model: NSManagedObjectModel) {
        let entity = NSEntityDescription()
        entity.name = "TimeBudgetEntity"
        entity.managedObjectClassName = "TimeBudgetEntity"
        
        // ID attribute
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        // Name attribute
        let nameAttribute = NSAttributeDescription()
        nameAttribute.name = "name"
        nameAttribute.attributeType = .stringAttributeType
        nameAttribute.isOptional = false
        
        // Total work minutes attribute
        let totalWorkMinutesAttribute = NSAttributeDescription()
        totalWorkMinutesAttribute.name = "totalWorkMinutes"
        totalWorkMinutesAttribute.attributeType = .doubleAttributeType
        totalWorkMinutesAttribute.defaultValue = 0.0
        
        // Period attribute
        let periodAttribute = NSAttributeDescription()
        periodAttribute.name = "period"
        periodAttribute.attributeType = .stringAttributeType
        periodAttribute.isOptional = false
        
        // Categories data attribute
        let categoriesDataAttribute = NSAttributeDescription()
        categoriesDataAttribute.name = "categoriesData"
        categoriesDataAttribute.attributeType = .binaryDataAttributeType
        categoriesDataAttribute.isOptional = false
        
        // Spending data attribute
        let spendingDataAttribute = NSAttributeDescription()
        spendingDataAttribute.name = "spendingData"
        spendingDataAttribute.attributeType = .binaryDataAttributeType
        spendingDataAttribute.isOptional = false
        
        // Created at attribute
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false
        
        // Period start date attribute
        let periodStartDateAttribute = NSAttributeDescription()
        periodStartDateAttribute.name = "periodStartDate"
        periodStartDateAttribute.attributeType = .dateAttributeType
        periodStartDateAttribute.isOptional = false
        
        entity.properties = [
            idAttribute,
            nameAttribute,
            totalWorkMinutesAttribute,
            periodAttribute,
            categoriesDataAttribute,
            spendingDataAttribute,
            createdAtAttribute,
            periodStartDateAttribute
        ]
        
        model.entities.append(entity)
    }
}

