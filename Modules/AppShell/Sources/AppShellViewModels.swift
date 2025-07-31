import CalcCore
import Combine
import CoreData
import Foundation
import HistoryStore
import os.log

// MARK: - Main App ViewModel

@available(iOS 15.0, *)
public class MainAppViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var needsOnboarding: Bool = true
    @Published public var quickPriceInput: String = ""
    @Published public var isValidQuickPrice: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared

    // MARK: - Computed Properties

    public var quickPrice: Double {
        return Double(quickPriceInput.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    public var quickWorkTime: Double {
        guard isValidQuickPrice,
              let hourlyWage = keychainManager.retrieveWage(),
              hourlyWage > 0
        else {
            return 0
        }

        return ConversionEngine.convertToWorkTime(price: quickPrice, hourlyWage: hourlyWage)
    }

    public var formattedQuickWorkTime: String {
        return ConversionEngine.formatWorkTime(quickWorkTime)
    }

    public var currencySymbol: String {
        let currency = keychainManager.retrieveCurrency()
        return CurrencyUtilities.symbol(for: currency)
    }

    // MARK: - Initialization

    public init() {
        setupBindings()
    }

    // MARK: - Public Methods

    public func checkOnboardingStatus() {
        needsOnboarding = !keychainManager.hasWage()
    }

    public func saveQuickCalculation() {
        guard isValidQuickPrice,
              let hourlyWage = keychainManager.retrieveWage()
        else {
            return
        }

        let context = DataController.shared.container.viewContext
        let calculation = Calculation(context: context)

        calculation.price = quickPrice
        calculation.currency = keychainManager.retrieveCurrency()
        calculation.minutes = quickWorkTime
        calculation.timestamp = Date()

        DataController.shared.save()

        // Clear input and provide feedback
        quickPriceInput = ""

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        $quickPriceInput
            .map { input in
                guard !input.isEmpty,
                      let price = Double(input.replacingOccurrences(of: ",", with: ".")),
                      price > 0
                else {
                    return false
                }
                return true
            }
            .assign(to: &$isValidQuickPrice)
    }
}

// MARK: - Settings ViewModel

@available(iOS 15.0, *)
public class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var wageInput: String = ""
    @Published public var selectedCurrency: String = ""
    @Published public var cloudSyncEnabled: Bool = true
    @Published public var showingClearDataAlert: Bool = false

    // MARK: - Private Properties

    private let keychainManager = KeychainManager.shared

    // MARK: - Initialization

    public init() {
        loadCurrentSettings()
    }

    // MARK: - Public Methods

    public func saveSettings() {
        // Save wage
        if let wage = Double(wageInput.replacingOccurrences(of: ",", with: ".")), wage > 0 {
            keychainManager.storeWage(wage)
        }

        // Save currency
        keychainManager.storeCurrency(selectedCurrency)

        // Update CoreData settings
        updateUserSettings()
    }

    public func clearAllData() {
        // Clear Keychain
        keychainManager.removeWage()
        keychainManager.removeCurrency()

        // Clear CoreData
        let context = DataController.shared.container.viewContext

        // Delete all calculations
        let calculationRequest: NSFetchRequest<NSFetchRequestResult> = Calculation.fetchRequest()
        let calculationDeleteRequest = NSBatchDeleteRequest(fetchRequest: calculationRequest)

        // Delete all user settings
        let settingsRequest: NSFetchRequest<NSFetchRequestResult> = UserSettings.fetchRequest()
        let settingsDeleteRequest = NSBatchDeleteRequest(fetchRequest: settingsRequest)

        do {
            try context.execute(calculationDeleteRequest)
            try context.execute(settingsDeleteRequest)
            DataController.shared.save()
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    log: .appShell,
                    "Failed to clear data: %{private}@",
                    String(describing: error)
                )
            #endif
        }
    }

    // MARK: - Private Methods

    private func loadCurrentSettings() {
        // Load wage
        if let wage = keychainManager.retrieveWage() {
            wageInput = String(format: "%.2f", wage)
        }

        // Load currency
        selectedCurrency = keychainManager.retrieveCurrency()

        // Load other settings from CoreData
        let context = DataController.shared.container.viewContext
        let request = UserSettings.current()

        do {
            let settings = try context.fetch(request)
            if let userSettings = settings.first {
                cloudSyncEnabled = userSettings.cloudSyncEnabled
            }
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    log: .appShell,
                    "Failed to load settings: %{private}@",
                    String(describing: error)
                )
            #endif
        }
    }

    private func updateUserSettings() {
        let context = DataController.shared.container.viewContext
        let request = UserSettings.current()

        do {
            let existingSettings = try context.fetch(request)
            let settings = existingSettings.first ?? UserSettings(context: context)

            settings.cloudSyncEnabled = cloudSyncEnabled
            settings.lastModified = Date()

            DataController.shared.save()
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    log: .appShell,
                    "Failed to update settings: %{private}@",
                    String(describing: error)
                )
            #endif
        }
    }
}

// MARK: - History ViewModel

@available(iOS 15.0, *)
public class HistoryViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var calculations: [Calculation] = []

    // MARK: - Private Properties

    private let context = DataController.shared.container.viewContext

    // MARK: - Initialization

    public init() {
        loadCalculations()
    }

    // MARK: - Public Methods

    public func loadCalculations() {
        let request = Calculation.allCalculations()

        do {
            calculations = try context.fetch(request)
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    log: .appShell,
                    "Failed to load calculations: %{private}@",
                    String(describing: error)
                )
            #endif
            calculations = []
        }
    }

    public func deleteCalculations(at offsets: IndexSet) {
        for index in offsets {
            let calculation = calculations[index]
            context.delete(calculation)
        }

        DataController.shared.save()
        loadCalculations() // Reload to update the list
    }

    public func deleteCalculation(_ calculation: Calculation) {
        context.delete(calculation)
        DataController.shared.save()
        loadCalculations()
    }

    public func clearAllCalculations() {
        let request: NSFetchRequest<NSFetchRequestResult> = Calculation.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            DataController.shared.save()
            loadCalculations()
        } catch {
            #if DEBUG
                os_log(
                    .error,
                    log: .appShell,
                    "Failed to clear calculations: %{private}@",
                    String(describing: error)
                )
            #endif
        }
    }
}

// MARK: - UIKit Integration

import UIKit

extension MainAppViewModel {
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
