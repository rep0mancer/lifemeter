import AppShell
import HistoryStore
import SwiftUI

// MARK: - Main App

@available(iOS 15.0, *)
@main
struct LifeMeterApp: App {
    // MARK: - Properties

    @StateObject private var dataController = DataController.shared
    @StateObject private var currencyStore = CurrencyStore()

    // MARK: - App Body

    var body: some Scene {
        WindowGroup {
            if let error = dataController.migrationError {
                FatalMigrationErrorView(error: error)
            } else {
                MainAppView()
                    .environment(\.managedObjectContext, dataController.container.viewContext)
                    .environmentObject(currencyStore)
                    .onAppear {
                        setupApp()
                    }
            }
        }
    }

    // MARK: - Setup

    private func setupApp() {
        // Configure app appearance
        configureAppearance()

        // Setup notifications if needed
        setupNotifications()

        // Perform any necessary migrations
        performDataMigrations()
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance if needed
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func setupNotifications() {
        // Request notification permissions if needed for future features
        // Currently not used as per privacy-first approach
    }

    private func performDataMigrations() {
        // Handle any necessary data migrations between app versions
        let userDefaults = UserDefaults.standard
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastVersion = userDefaults.string(forKey: "LastAppVersion") ?? "0.0.0"

        if lastVersion != currentVersion {
            // Perform version-specific migrations here
            userDefaults.set(currentVersion, forKey: "LastAppVersion")
        }
    }
}

// MARK: - App Configuration

extension LifeMeterApp {
    /// App configuration constants
    enum Config {
        static let appCostEUR: Double = 2.99
        static let supportedCurrencies = ["EUR", "USD", "GBP", "JPY", "CHF", "CAD", "AUD"]
        static let defaultCurrency = "EUR"
        static let widgetRefreshInterval: TimeInterval = 900 // 15 minutes
        static let maxCalculationHistory = 1000
        static let appStoreID = "123456789" // To be updated with actual App Store ID
    }
}
