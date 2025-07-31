import Combine

// swiftlint:disable force_unwrapping
import Foundation
import SwiftUI
import os.log

// MARK: - Time Budget Planner

@available(iOS 15.0, *)
public class TimeBudgetPlanner: BaseViewModel {
    // MARK: - Published Properties

    @Published public var budgets: [TimeBudget] = []
    @Published public var currentBudget: TimeBudget?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // MARK: - Properties

    private let storage = TimeBudgetStorage.shared
    private let calculator = TimeBudgetCalculator()

    // MARK: - Initialization

    override public init() {
        super.init()
        loadBudgets()
        setupNotifications()
    }

    // MARK: - Public Methods

    /// Create a new time budget
    public func createBudget(
        name: String,
        totalWorkMinutes: Double,
        period: BudgetPeriod,
        categories: [BudgetCategory]
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TimeBudgetError.invalidName
        }

        guard totalWorkMinutes > 0 else {
            throw TimeBudgetError.invalidWorkTime
        }

        guard !categories.isEmpty else {
            throw TimeBudgetError.noCategoriesProvided
        }

        // Validate categories don't exceed total time
        let totalCategoryMinutes = categories.reduce(0) { $0 + $1.allocatedMinutes }
        guard totalCategoryMinutes <= totalWorkMinutes else {
            throw TimeBudgetError.categoriesExceedTotal
        }

        let budget = TimeBudget(
            name: name,
            totalWorkMinutes: totalWorkMinutes,
            period: period,
            categories: categories
        )

        budgets.append(budget)
        currentBudget = budget

        try storage.saveBudgets(budgets)

        logBudgetEvent(.budgetCreated, budgetId: budget.id, details: "Budget '\(name)' created")
    }

    /// Update an existing budget
    public func updateBudget(_ budget: TimeBudget) throws {
        guard let index = budgets.firstIndex(where: { $0.id == budget.id }) else {
            throw TimeBudgetError.budgetNotFound
        }

        budgets[index] = budget

        if currentBudget?.id == budget.id {
            currentBudget = budget
        }

        try storage.saveBudgets(budgets)

        logBudgetEvent(.budgetUpdated, budgetId: budget.id, details: "Budget updated")
    }

    /// Delete a budget
    public func deleteBudget(_ budget: TimeBudget) throws {
        budgets.removeAll { $0.id == budget.id }

        if currentBudget?.id == budget.id {
            currentBudget = budgets.first
        }

        try storage.saveBudgets(budgets)

        logBudgetEvent(.budgetDeleted, budgetId: budget.id, details: "Budget deleted")
    }

    /// Set the active budget
    public func setActiveBudget(_ budget: TimeBudget) {
        currentBudget = budget
        logBudgetEvent(.budgetActivated, budgetId: budget.id, details: "Budget activated")
    }

    /// Track spending against current budget
    public func trackSpending(amount: Double, currency: String, category: String) throws {
        guard let budget = currentBudget else {
            throw TimeBudgetError.noBudgetSelected
        }

        guard let hourlyWage = getHourlyWage() else {
            throw TimeBudgetError.noWageConfigured
        }

        let workMinutes = calculator.calculateWorkMinutes(
            amount: amount,
            hourlyWage: hourlyWage
        )

        let spending = BudgetSpending(
            amount: amount,
            currency: currency,
            workMinutes: workMinutes,
            category: category,
            timestamp: Date()
        )

        var updatedBudget = budget
        updatedBudget.addSpending(spending)

        try updateBudget(updatedBudget)

        // Check for budget alerts
        checkBudgetAlerts(for: updatedBudget, spending: spending)

        logBudgetEvent(.spendingTracked, budgetId: budget.id, details: "Spending tracked: \(amount) \(currency)")
    }

    /// Get budget summary for current period
    public func getBudgetSummary() -> BudgetSummary? {
        guard let budget = currentBudget else { return nil }

        return calculator.calculateBudgetSummary(budget)
    }

    /// Get spending breakdown by category
    public func getSpendingBreakdown() -> [CategorySpending] {
        guard let budget = currentBudget else { return [] }

        return calculator.calculateCategorySpending(budget)
    }

    /// Get budget progress for visualization
    public func getBudgetProgress() -> BudgetProgress? {
        guard let budget = currentBudget else { return nil }

        return calculator.calculateBudgetProgress(budget)
    }

    /// Reset budget for new period
    public func resetBudgetForNewPeriod() throws {
        guard var budget = currentBudget else {
            throw TimeBudgetError.noBudgetSelected
        }

        budget.resetForNewPeriod()
        try updateBudget(budget)

        logBudgetEvent(.budgetReset, budgetId: budget.id, details: "Budget reset for new period")
    }

    // MARK: - Private Methods

    private func loadBudgets() {
        isLoading = true

        do {
            budgets = try storage.loadBudgets()
            currentBudget = budgets.first
        } catch {
            errorMessage = "Failed to load budgets: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func setupNotifications() {
        // Listen for wage changes
        NotificationCenter.default.publisher(for: .wageUpdated)
            .store(in: self) { _ in
                // Recalculate all spending with new wage
                self.recalculateSpendingWithNewWage()
            }
    }

    private func recalculateSpendingWithNewWage() {
        guard let hourlyWage = getHourlyWage() else { return }

        for (index, budget) in budgets.enumerated() {
            var updatedBudget = budget

            // Recalculate work minutes for all spending
            for (spendingIndex, spending) in budget.spending.enumerated() {
                let newWorkMinutes = calculator.calculateWorkMinutes(
                    amount: spending.amount,
                    hourlyWage: hourlyWage
                )
                updatedBudget.spending[spendingIndex].workMinutes = newWorkMinutes
            }

            budgets[index] = updatedBudget
        }

        if let currentId = currentBudget?.id {
            currentBudget = budgets.first { $0.id == currentId }
        }

        try? storage.saveBudgets(budgets)
    }

    private func getHourlyWage() -> Double? {
        // Get wage from Keychain
        do {
            let wageData = try HardenedKeychainManager.shared.loadWage()
            return wageData?.amount
        } catch {
            return nil
        }
    }

    private func checkBudgetAlerts(for budget: TimeBudget, spending _: BudgetSpending) {
        let summary = calculator.calculateBudgetSummary(budget)

        // Check overall budget alert
        if summary.usedPercentage >= 0.8, summary.usedPercentage < 0.9 {
            sendBudgetAlert(.approaching80Percent, budget: budget)
        } else if summary.usedPercentage >= 0.9, summary.usedPercentage < 1.0 {
            sendBudgetAlert(.approaching90Percent, budget: budget)
        } else if summary.usedPercentage >= 1.0 {
            sendBudgetAlert(.budgetExceeded, budget: budget)
        }

        // Check category-specific alerts
        let categorySpending = calculator.calculateCategorySpending(budget)
        for category in categorySpending {
            if category.usedPercentage >= 1.0 {
                sendCategoryAlert(.categoryExceeded, budget: budget, category: category.name)
            } else if category.usedPercentage >= 0.9 {
                sendCategoryAlert(.categoryApproaching90Percent, budget: budget, category: category.name)
            }
        }
    }

    private func sendBudgetAlert(_ type: BudgetAlertType, budget: TimeBudget) {
        let alert = BudgetAlert(
            type: type,
            budgetId: budget.id,
            budgetName: budget.name,
            message: type.message(for: budget.name),
            timestamp: Date()
        )

        NotificationCenter.default.post(
            name: .budgetAlert,
            object: alert
        )

        logBudgetEvent(.alertTriggered, budgetId: budget.id, details: type.rawValue)
    }

    private func sendCategoryAlert(_ type: CategoryAlertType, budget: TimeBudget, category: String) {
        let alert = CategoryAlert(
            type: type,
            budgetId: budget.id,
            budgetName: budget.name,
            categoryName: category,
            message: type.message(for: category),
            timestamp: Date()
        )

        NotificationCenter.default.post(
            name: .categoryAlert,
            object: alert
        )

        logBudgetEvent(.categoryAlertTriggered, budgetId: budget.id, details: "\(type.rawValue) - \(category)")
    }

    private func logBudgetEvent(_ event: BudgetEvent, budgetId _: UUID, details: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        #if DEBUG
            os_log(.debug, "\u{1F4B0} Budget Event [%{public}@]: %{public}@ - %{public}@",
                   timestamp, event.rawValue, details)
        #endif

        // In production, log to analytics or audit trail
    }
}

// MARK: - Time Budget Model

public struct TimeBudget: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let totalWorkMinutes: Double
    public let period: BudgetPeriod
    public var categories: [BudgetCategory]
    public var spending: [BudgetSpending] = []
    public let createdAt: Date
    public var periodStartDate: Date

    public init(
        name: String,
        totalWorkMinutes: Double,
        period: BudgetPeriod,
        categories: [BudgetCategory]
    ) {
        self.name = name
        self.totalWorkMinutes = totalWorkMinutes
        self.period = period
        self.categories = categories
        createdAt = Date()
        periodStartDate = Date()
    }

    public mutating func addSpending(_ spending: BudgetSpending) {
        self.spending.append(spending)
    }

    public mutating func resetForNewPeriod() {
        spending.removeAll()
        periodStartDate = Date()
    }

    public var isCurrentPeriod: Bool {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .daily:
            return calendar.isDate(periodStartDate, inSameDayAs: now)
        case .weekly:
            return calendar.isDate(periodStartDate, equalTo: now, toGranularity: .weekOfYear)
        case .monthly:
            return calendar.isDate(periodStartDate, equalTo: now, toGranularity: .month)
        case .yearly:
            return calendar.isDate(periodStartDate, equalTo: now, toGranularity: .year)
        }
    }
}

// MARK: - Budget Category

public struct BudgetCategory: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let allocatedMinutes: Double
    public let color: String // Hex color code
    public let icon: String // SF Symbol name

    public init(name: String, allocatedMinutes: Double, color: String, icon: String) {
        self.name = name
        self.allocatedMinutes = allocatedMinutes
        self.color = color
        self.icon = icon
    }
}

// MARK: - Budget Spending

public struct BudgetSpending: Identifiable, Codable {
    public let id = UUID()
    public let amount: Double
    public let currency: String
    public var workMinutes: Double
    public let category: String
    public let timestamp: Date

    public init(amount: Double, currency: String, workMinutes: Double, category: String, timestamp: Date) {
        self.amount = amount
        self.currency = currency
        self.workMinutes = workMinutes
        self.category = category
        self.timestamp = timestamp
    }
}

// MARK: - Budget Period

public enum BudgetPeriod: String, CaseIterable, Codable {
    case daily
    case weekly
    case monthly
    case yearly

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    public var description: String {
        switch self {
        case .daily: return "Reset every day"
        case .weekly: return "Reset every week"
        case .monthly: return "Reset every month"
        case .yearly: return "Reset every year"
        }
    }
}

// MARK: - Budget Summary

public struct BudgetSummary {
    public let totalAllocatedMinutes: Double
    public let totalUsedMinutes: Double
    public let remainingMinutes: Double
    public let usedPercentage: Double
    public let isOverBudget: Bool

    public var formattedUsedTime: String {
        return TimeFormatter.formatMinutes(totalUsedMinutes)
    }

    public var formattedRemainingTime: String {
        return TimeFormatter.formatMinutes(remainingMinutes)
    }

    public var formattedTotalTime: String {
        return TimeFormatter.formatMinutes(totalAllocatedMinutes)
    }
}

// MARK: - Category Spending

public struct CategorySpending {
    public let name: String
    public let allocatedMinutes: Double
    public let usedMinutes: Double
    public let remainingMinutes: Double
    public let usedPercentage: Double
    public let color: String
    public let icon: String

    public var isOverBudget: Bool {
        return usedMinutes > allocatedMinutes
    }

    public var formattedUsedTime: String {
        return TimeFormatter.formatMinutes(usedMinutes)
    }

    public var formattedRemainingTime: String {
        return TimeFormatter.formatMinutes(remainingMinutes)
    }
}

// MARK: - Budget Progress

public struct BudgetProgress {
    public let overallProgress: Double
    public let categoryProgress: [CategoryProgress]
    public let timeRemaining: TimeInterval
    public let projectedOverage: Double?

    public var isOnTrack: Bool {
        return projectedOverage == nil || projectedOverage! <= 0
    }
}

public struct CategoryProgress {
    public let name: String
    public let progress: Double
    public let color: String
    public let isOverBudget: Bool
}

// MARK: - Time Budget Calculator

public class TimeBudgetCalculator {
    public init() {}

    public func calculateWorkMinutes(amount: Double, hourlyWage: Double) -> Double {
        guard hourlyWage > 0 else { return 0 }
        return (amount / hourlyWage) * 60.0
    }

    public func calculateBudgetSummary(_ budget: TimeBudget) -> BudgetSummary {
        let totalAllocated = budget.totalWorkMinutes
        let totalUsed = budget.spending.reduce(0) { $0 + $1.workMinutes }
        let remaining = max(0, totalAllocated - totalUsed)
        let usedPercentage = totalAllocated > 0 ? totalUsed / totalAllocated : 0

        return BudgetSummary(
            totalAllocatedMinutes: totalAllocated,
            totalUsedMinutes: totalUsed,
            remainingMinutes: remaining,
            usedPercentage: usedPercentage,
            isOverBudget: totalUsed > totalAllocated
        )
    }

    public func calculateCategorySpending(_ budget: TimeBudget) -> [CategorySpending] {
        return budget.categories.map { category in
            let categorySpending = budget.spending.filter { $0.category == category.name }
            let usedMinutes = categorySpending.reduce(0) { $0 + $1.workMinutes }
            let remaining = max(0, category.allocatedMinutes - usedMinutes)
            let usedPercentage = category.allocatedMinutes > 0 ? usedMinutes / category.allocatedMinutes : 0

            return CategorySpending(
                name: category.name,
                allocatedMinutes: category.allocatedMinutes,
                usedMinutes: usedMinutes,
                remainingMinutes: remaining,
                usedPercentage: usedPercentage,
                color: category.color,
                icon: category.icon
            )
        }
    }

    public func calculateBudgetProgress(_ budget: TimeBudget) -> BudgetProgress {
        let summary = calculateBudgetSummary(budget)
        let categorySpending = calculateCategorySpending(budget)

        let categoryProgress = categorySpending.map { category in
            CategoryProgress(
                name: category.name,
                progress: category.usedPercentage,
                color: category.color,
                isOverBudget: category.isOverBudget
            )
        }

        // Calculate time remaining in current period
        let timeRemaining = calculateTimeRemainingInPeriod(budget.period, startDate: budget.periodStartDate)

        // Project potential overage based on current spending rate
        let projectedOverage = calculateProjectedOverage(budget, timeRemaining: timeRemaining)

        return BudgetProgress(
            overallProgress: summary.usedPercentage,
            categoryProgress: categoryProgress,
            timeRemaining: timeRemaining,
            projectedOverage: projectedOverage
        )
    }

    private func calculateTimeRemainingInPeriod(_ period: BudgetPeriod, startDate: Date) -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()

        let endDate: Date
        switch period {
        case .daily:
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? now
        case .weekly:
            endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? now
        case .monthly:
            endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? now
        case .yearly:
            endDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? now
        }

        return max(0, endDate.timeIntervalSince(now))
    }

    private func calculateProjectedOverage(_ budget: TimeBudget, timeRemaining: TimeInterval) -> Double? {
        guard timeRemaining > 0 else { return nil }

        let periodDuration = getPeriodDuration(budget.period)
        let timeElapsed = periodDuration - timeRemaining

        guard timeElapsed > 0 else { return nil }

        let currentSpendingRate = budget.spending.reduce(0) { $0 + $1.workMinutes } / (timeElapsed / 60.0) // minutes per minute
        let projectedTotalSpending = currentSpendingRate * (periodDuration / 60.0)

        return max(0, projectedTotalSpending - budget.totalWorkMinutes)
    }

    private func getPeriodDuration(_ period: BudgetPeriod) -> TimeInterval {
        switch period {
        case .daily: return 24 * 60 * 60 // 1 day
        case .weekly: return 7 * 24 * 60 * 60 // 1 week
        case .monthly: return 30 * 24 * 60 * 60 // ~1 month
        case .yearly: return 365 * 24 * 60 * 60 // ~1 year
        }
    }
}

// MARK: - Time Formatter

public class TimeFormatter {
    public static func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes / 60)
        let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }

    public static func formatHours(_ minutes: Double) -> String {
        let hours = minutes / 60.0
        return String(format: "%.1fh", hours)
    }
}

// MARK: - Errors and Events

public enum TimeBudgetError: LocalizedError {
    case invalidName
    case invalidWorkTime
    case noCategoriesProvided
    case categoriesExceedTotal
    case budgetNotFound
    case noBudgetSelected
    case noWageConfigured
    case storageFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Budget name cannot be empty"
        case .invalidWorkTime:
            return "Work time must be greater than zero"
        case .noCategoriesProvided:
            return "At least one category is required"
        case .categoriesExceedTotal:
            return "Category allocations exceed total work time"
        case .budgetNotFound:
            return "Budget not found"
        case .noBudgetSelected:
            return "No budget is currently selected"
        case .noWageConfigured:
            return "Hourly wage is not configured"
        case let .storageFailed(error):
            return "Storage failed: \(error.localizedDescription)"
        }
    }
}

private enum BudgetEvent: String {
    case budgetCreated = "BUDGET_CREATED"
    case budgetUpdated = "BUDGET_UPDATED"
    case budgetDeleted = "BUDGET_DELETED"
    case budgetActivated = "BUDGET_ACTIVATED"
    case budgetReset = "BUDGET_RESET"
    case spendingTracked = "SPENDING_TRACKED"
    case alertTriggered = "ALERT_TRIGGERED"
    case categoryAlertTriggered = "CATEGORY_ALERT_TRIGGERED"
}

// MARK: - Alert Types

public enum BudgetAlertType: String {
    case approaching80Percent = "APPROACHING_80_PERCENT"
    case approaching90Percent = "APPROACHING_90_PERCENT"
    case budgetExceeded = "BUDGET_EXCEEDED"

    public func message(for budgetName: String) -> String {
        switch self {
        case .approaching80Percent:
            return "You've used 80% of your '\(budgetName)' budget"
        case .approaching90Percent:
            return "You've used 90% of your '\(budgetName)' budget"
        case .budgetExceeded:
            return "You've exceeded your '\(budgetName)' budget"
        }
    }
}

public enum CategoryAlertType: String {
    case categoryApproaching90Percent = "CATEGORY_APPROACHING_90_PERCENT"
    case categoryExceeded = "CATEGORY_EXCEEDED"

    public func message(for categoryName: String) -> String {
        switch self {
        case .categoryApproaching90Percent:
            return "You've used 90% of your '\(categoryName)' category budget"
        case .categoryExceeded:
            return "You've exceeded your '\(categoryName)' category budget"
        }
    }
}

public struct BudgetAlert {
    public let type: BudgetAlertType
    public let budgetId: UUID
    public let budgetName: String
    public let message: String
    public let timestamp: Date
}

public struct CategoryAlert {
    public let type: CategoryAlertType
    public let budgetId: UUID
    public let budgetName: String
    public let categoryName: String
    public let message: String
    public let timestamp: Date
}

// MARK: - Notification Names

extension Notification.Name {
    static let budgetAlert = Notification.Name("budgetAlert")
    static let categoryAlert = Notification.Name("categoryAlert")
    static let wageUpdated = Notification.Name("wageUpdated")
}
