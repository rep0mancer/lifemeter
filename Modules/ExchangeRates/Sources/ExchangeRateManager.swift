import Foundation
import Combine

// MARK: - Exchange Rate Manager
@available(iOS 15.0, *)
public class ExchangeRateManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = ExchangeRateManager()
    
    // MARK: - Published Properties
    @Published public var exchangeRates: [String: Double] = [:]
    @Published public var lastUpdateTime: Date?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // MARK: - Properties
    private let settings = ExchangeRateSettings.shared
    private let storage = ExchangeRateStorage.shared
    private let apiClient = ExchangeRateAPIClient()
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private let updateInterval: TimeInterval = 3600 // 1 hour
    private let maxCacheAge: TimeInterval = 86400 // 24 hours
    
    // MARK: - Initialization
    private init() {
        loadCachedRates()
        setupAutoUpdate()
    }
    
    // MARK: - Public Methods
    
    /// Enable exchange rate updates with user consent
    public func enableExchangeRates() {
        settings.isExchangeRateEnabled = true
        settings.hasUserConsent = true
        
        refreshRates()
        setupAutoUpdate()
        
        logExchangeEvent(.exchangeRatesEnabled, details: "User enabled exchange rates")
    }
    
    /// Disable exchange rate updates
    public func disableExchangeRates() {
        settings.isExchangeRateEnabled = false
        
        stopAutoUpdate()
        clearCachedRates()
        
        logExchangeEvent(.exchangeRatesDisabled, details: "User disabled exchange rates")
    }
    
    /// Get exchange rate between two currencies
    public func getExchangeRate(from: String, to: String) -> Double? {
        guard settings.isExchangeRateEnabled else { return nil }
        
        // If same currency, return 1.0
        if from == to { return 1.0 }
        
        // Try direct rate
        if let rate = exchangeRates["\(from)_\(to)"] {
            return rate
        }
        
        // Try inverse rate
        if let inverseRate = exchangeRates["\(to)_\(from)"] {
            return 1.0 / inverseRate
        }
        
        // Try via USD as base currency
        if let fromUSD = exchangeRates["USD_\(from)"],
           let toUSD = exchangeRates["USD_\(to)"] {
            return toUSD / fromUSD
        }
        
        return nil
    }
    
    /// Convert amount between currencies
    public func convertCurrency(amount: Double, from: String, to: String) -> Double? {
        guard let rate = getExchangeRate(from: from, to: to) else {
            return nil
        }
        
        return amount * rate
    }
    
    /// Check if exchange rates are available for currency pair
    public func isExchangeRateAvailable(from: String, to: String) -> Bool {
        return getExchangeRate(from: from, to: to) != nil
    }
    
    /// Manually refresh exchange rates
    public func refreshRates() {
        guard settings.isExchangeRateEnabled && settings.hasUserConsent else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        apiClient.fetchExchangeRates()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.logExchangeEvent(.fetchFailed, details: error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] rates in
                    self?.updateExchangeRates(rates)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Get supported currencies
    public func getSupportedCurrencies() -> [String] {
        return Array(Set(exchangeRates.keys.flatMap { key in
            key.split(separator: "_").map(String.init)
        })).sorted()
    }
    
    /// Get exchange rate status
    public func getExchangeRateStatus() -> ExchangeRateStatus {
        return ExchangeRateStatus(
            isEnabled: settings.isExchangeRateEnabled,
            hasUserConsent: settings.hasUserConsent,
            lastUpdateTime: lastUpdateTime,
            availableCurrencies: getSupportedCurrencies().count,
            isDataFresh: isDataFresh()
        )
    }
    
    /// Show privacy consent dialog
    public func showPrivacyConsent(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Enable Live Exchange Rates?",
            message: createPrivacyConsentMessage(),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Learn More", style: .default) { _ in
            self.showDetailedPrivacyInfo(from: viewController, completion: completion)
        })
        
        alert.addAction(UIAlertAction(title: "Enable", style: .default) { _ in
            self.enableExchangeRates()
            completion(true)
        })
        
        alert.addAction(UIAlertAction(title: "Keep Offline", style: .cancel) { _ in
            completion(false)
        })
        
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Private Methods
    
    private func loadCachedRates() {
        do {
            let cachedData = try storage.loadExchangeRates()
            exchangeRates = cachedData.rates
            lastUpdateTime = cachedData.timestamp
        } catch {
            logExchangeEvent(.cacheLoadFailed, details: error.localizedDescription)
        }
    }
    
    private func updateExchangeRates(_ rates: [String: Double]) {
        exchangeRates = rates
        lastUpdateTime = Date()
        
        // Save to cache
        do {
            try storage.saveExchangeRates(rates, timestamp: Date())
            logExchangeEvent(.ratesUpdated, details: "Updated \(rates.count) exchange rates")
        } catch {
            logExchangeEvent(.cacheSaveFailed, details: error.localizedDescription)
        }
    }
    
    private func setupAutoUpdate() {
        guard settings.isExchangeRateEnabled else { return }
        
        stopAutoUpdate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.refreshRates()
        }
        
        // Initial refresh if data is stale
        if !isDataFresh() {
            refreshRates()
        }
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func isDataFresh() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return false }
        return Date().timeIntervalSince(lastUpdate) < maxCacheAge
    }
    
    private func clearCachedRates() {
        exchangeRates.removeAll()
        lastUpdateTime = nil
        
        do {
            try storage.clearExchangeRates()
        } catch {
            logExchangeEvent(.cacheClearFailed, details: error.localizedDescription)
        }
    }
    
    private func createPrivacyConsentMessage() -> String {
        return """
        LifeMeter can fetch live exchange rates to provide accurate currency conversions.
        
        🔒 Your privacy is protected:
        • Only exchange rate data is fetched
        • No personal information is sent
        • You can disable this anytime in Settings
        • All calculations remain local
        
        This feature is optional and LifeMeter works perfectly without it.
        """
    }
    
    private func showDetailedPrivacyInfo(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Exchange Rate Privacy Details",
            message: createDetailedPrivacyMessage(),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Enable", style: .default) { _ in
            self.enableExchangeRates()
            completion(true)
        })
        
        alert.addAction(UIAlertAction(title: "Keep Offline", style: .cancel) { _ in
            completion(false)
        })
        
        viewController.present(alert, animated: true)
    }
    
    private func createDetailedPrivacyMessage() -> String {
        return """
        WHAT DATA IS FETCHED:
        • Current exchange rates between major currencies
        • No personal or financial information
        
        HOW IT WORKS:
        • Rates are fetched from a public API service
        • Data is cached locally for 24 hours
        • Updates happen automatically every hour
        
        YOUR PRIVACY:
        • No tracking or analytics
        • No personal data is sent
        • Your wage and calculations remain private
        • You can disable this feature anytime
        
        OFFLINE MODE:
        • LifeMeter works perfectly without exchange rates
        • Manual currency entry is always available
        • All core features remain functional
        """
    }
    
    private func logExchangeEvent(_ event: ExchangeRateEvent, details: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        #if DEBUG
        print("💱 Exchange Rate Event [\(timestamp)]: \(event.rawValue) - \(details)")
        #endif
        
        // In production, log to analytics (without personal data)
    }
}

// MARK: - Exchange Rate API Client
@available(iOS 15.0, *)
public class ExchangeRateAPIClient {
    
    // MARK: - Properties
    private let session = URLSession.shared
    private let baseURL = "https://api.exchangerate-api.com/v4/latest"
    
    // MARK: - Public Methods
    
    /// Fetch current exchange rates
    public func fetchExchangeRates(baseCurrency: String = "USD") -> AnyPublisher<[String: Double], ExchangeRateError> {
        guard let url = URL(string: "\(baseURL)/\(baseCurrency)") else {
            return Fail(error: ExchangeRateError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue("LifeMeter/1.0", forHTTPHeaderField: "User-Agent")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ExchangeRateResponse.self, decoder: JSONDecoder())
            .map { response in
                // Convert to our format with currency pairs
                var rates: [String: Double] = [:]
                
                for (currency, rate) in response.rates {
                    rates["\(baseCurrency)_\(currency)"] = rate
                }
                
                return rates
            }
            .mapError { error in
                if error is DecodingError {
                    return ExchangeRateError.invalidResponse
                } else {
                    return ExchangeRateError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Exchange Rate Response
private struct ExchangeRateResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - Exchange Rate Settings
public class ExchangeRateSettings {
    
    // MARK: - Singleton
    public static let shared = ExchangeRateSettings()
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    
    public var isExchangeRateEnabled: Bool {
        get {
            return userDefaults.bool(forKey: "exchange_rate.enabled")
        }
        set {
            userDefaults.set(newValue, forKey: "exchange_rate.enabled")
        }
    }
    
    public var hasUserConsent: Bool {
        get {
            return userDefaults.bool(forKey: "exchange_rate.user_consent")
        }
        set {
            userDefaults.set(newValue, forKey: "exchange_rate.user_consent")
        }
    }
    
    public var autoUpdateEnabled: Bool {
        get {
            return userDefaults.bool(forKey: "exchange_rate.auto_update")
        }
        set {
            userDefaults.set(newValue, forKey: "exchange_rate.auto_update")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Set default values
        if !userDefaults.bool(forKey: "exchange_rate.defaults_set") {
            isExchangeRateEnabled = false // Default to disabled for privacy
            hasUserConsent = false
            autoUpdateEnabled = true
            userDefaults.set(true, forKey: "exchange_rate.defaults_set")
        }
    }
}

// MARK: - Exchange Rate Storage
public class ExchangeRateStorage {
    
    // MARK: - Singleton
    public static let shared = ExchangeRateStorage()
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// Save exchange rates to cache
    public func saveExchangeRates(_ rates: [String: Double], timestamp: Date) throws {
        let cacheData = ExchangeRateCacheData(rates: rates, timestamp: timestamp)
        let data = try encoder.encode(cacheData)
        userDefaults.set(data, forKey: "exchange_rate.cache")
    }
    
    /// Load exchange rates from cache
    public func loadExchangeRates() throws -> ExchangeRateCacheData {
        guard let data = userDefaults.data(forKey: "exchange_rate.cache") else {
            throw ExchangeRateError.noCachedData
        }
        
        return try decoder.decode(ExchangeRateCacheData.self, from: data)
    }
    
    /// Clear cached exchange rates
    public func clearExchangeRates() throws {
        userDefaults.removeObject(forKey: "exchange_rate.cache")
    }
}

// MARK: - Exchange Rate Cache Data
public struct ExchangeRateCacheData: Codable {
    public let rates: [String: Double]
    public let timestamp: Date
}

// MARK: - Exchange Rate Status
public struct ExchangeRateStatus {
    public let isEnabled: Bool
    public let hasUserConsent: Bool
    public let lastUpdateTime: Date?
    public let availableCurrencies: Int
    public let isDataFresh: Bool
    
    public var statusDescription: String {
        if !isEnabled {
            return "Disabled"
        } else if !hasUserConsent {
            return "Consent Required"
        } else if !isDataFresh {
            return "Data Stale"
        } else {
            return "Active"
        }
    }
}

// MARK: - Exchange Rate Error
public enum ExchangeRateError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case noCachedData
    case consentRequired
    case serviceUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid exchange rate service URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from exchange rate service"
        case .noCachedData:
            return "No cached exchange rate data available"
        case .consentRequired:
            return "User consent required for exchange rate updates"
        case .serviceUnavailable:
            return "Exchange rate service is currently unavailable"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL, .invalidResponse:
            return "Please try again later or contact support"
        case .networkError:
            return "Check your internet connection and try again"
        case .noCachedData:
            return "Enable exchange rates to fetch current data"
        case .consentRequired:
            return "Enable exchange rates in Settings"
        case .serviceUnavailable:
            return "The service will be restored shortly"
        }
    }
}

// MARK: - Exchange Rate Event
private enum ExchangeRateEvent: String {
    case exchangeRatesEnabled = "EXCHANGE_RATES_ENABLED"
    case exchangeRatesDisabled = "EXCHANGE_RATES_DISABLED"
    case ratesUpdated = "RATES_UPDATED"
    case fetchFailed = "FETCH_FAILED"
    case cacheLoadFailed = "CACHE_LOAD_FAILED"
    case cacheSaveFailed = "CACHE_SAVE_FAILED"
    case cacheClearFailed = "CACHE_CLEAR_FAILED"
}

