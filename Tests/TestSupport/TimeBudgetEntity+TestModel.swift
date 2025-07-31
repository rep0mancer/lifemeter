import CoreData

/// Adds the `TimeBudgetEntity` description to an in-memory `NSManagedObjectModel` for tests.
///
/// Tests use lightweight Core Data stacks without the full application model.
/// This helper ensures the model includes the entity required by `TimeBudgetStorage`.
func addTimeBudgetEntity(to model: NSManagedObjectModel) {
    guard model.entitiesByName["TimeBudgetEntity"] == nil else { return }

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
