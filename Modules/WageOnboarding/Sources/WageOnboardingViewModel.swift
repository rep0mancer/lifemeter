import CalcCore
import Combine
import Foundation
import HistoryStore

// MARK: - Wage Onboarding ViewModel

@available(iOS 15.0, *)
public class WageOnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var wageInput: String = ""
    @Published public var selectedPeriod: PayPeriod = .monthly
    @Published public var selectedCurrency: String = ""
    @Published public var showThankYouModal: Bool = false
    @Published public var isValidInput: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let keychainManager = KeychainManager.shared
    private let appCostEUR: Double = 2.99

    // MARK: - Computed Properties

    public var hourlyWage: Double {
        guard let wage = Double(wageInput.replacingOccurrences(of: ",", with: ".")) else {
            return 0
        }
        return wage / selectedPeriod.hoursMultiplier
    }

    public var appCostWorkTime: Double {
        guard hourlyWage > 0 else { return 0 }

        // Convert app cost to user's currency if needed
        let appCostInUserCurrency = convertCurrency(from: appCostEUR, fromCurrency: "EUR", toCurrency: selectedCurrency)

        return ConversionEngine.convertToWorkTime(price: appCostInUserCurrency, hourlyWage: hourlyWage)
    }

    // MARK: - Initialization

    public init() {
        setupBindings()
        loadInitialValues()
    }

    // MARK: - Public Methods

    public func saveWageAndShowThankYou() {
        guard isValidInput else { return }

        // Save wage and currency to Keychain
        keychainManager.storeWage(hourlyWage)
        keychainManager.storeCurrency(selectedCurrency)

        // Update CoreData settings
        updateUserSettings()

        // Show thank you modal
        showThankYouModal = true

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Validate input whenever wage input or period changes
        Publishers.CombineLatest($wageInput, $selectedPeriod)
            .map { [weak self] wageInput, _ in
                self?.validateInput(wageInput) ?? false
            }
            .assign(to: &$isValidInput)
    }

    private func loadInitialValues() {
        // Set default currency from locale
        selectedCurrency = Locale.current.currencyCode ?? "EUR"

        // Load existing wage if available (for editing)
        if let existingWage = keychainManager.retrieveWage() {
            wageInput = String(format: "%.2f", existingWage * selectedPeriod.hoursMultiplier)
        }

        if let existingCurrency = keychainManager.retrieveCurrency() {
            selectedCurrency = existingCurrency
        }
    }

    private func validateInput(_ input: String) -> Bool {
        guard !input.isEmpty else { return false }

        let cleanInput = input.replacingOccurrences(of: ",", with: ".")
        guard let wage = Double(cleanInput), wage > 0 else { return false }

        // Ensure hourly wage is reasonable (between 0.01 and 10000 per hour)
        let hourlyRate = wage / selectedPeriod.hoursMultiplier
        return hourlyRate >= 0.01 && hourlyRate <= 10000
    }

    private func updateUserSettings() {
        let context = DataController.shared.container.viewContext

        // Fetch or create user settings
        let request = UserSettings.current()
        let settings: UserSettings

        do {
            let existingSettings = try context.fetch(request)
            settings = existingSettings.first ?? UserSettings(context: context)
        } catch {
            settings = UserSettings(context: context)
        }

        // Update settings
        settings.hourlyWage = hourlyWage
        settings.currency = selectedCurrency
        settings.hasCompletedOnboarding = true
        settings.lastModified = Date()

        // Save context
        DataController.shared.save()
    }

    private func convertCurrency(from amount: Double, fromCurrency: String, toCurrency: String) -> Double {
        // For MVP, use simplified conversion rates
        // In production, this would use real exchange rates
        let exchangeRates: [String: Double] = [
            "EUR": 1.0,
            "USD": 1.1,
            "GBP": 0.85,
            "JPY": 130.0,
            "CHF": 0.95,
            "CAD": 1.35,
            "AUD": 1.45,
        ]

        guard let fromRate = exchangeRates[fromCurrency],
              let toRate = exchangeRates[toCurrency]
        else {
            return amount // Return original if conversion not available
        }

        // Convert to EUR first, then to target currency
        let eurAmount = amount / fromRate
        return eurAmount * toRate
    }
}

// MARK: - UIKit Integration

import UIKit

extension WageOnboardingViewModel {
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}
