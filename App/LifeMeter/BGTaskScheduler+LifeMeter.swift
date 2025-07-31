import BackgroundTasks
import ExchangeRates
import CalcCore

extension BGTaskScheduler {
    static let ratesRefreshIdentifier = "com.rep0mancer.lifemeter.rates-refresh"

    static func registerLifeMeterTasks(
        exchangeRates: ExchangeRateManager = ExchangeRateManager(),
        currency: CurrencyStore = CurrencyStore()
    ) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: ratesRefreshIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await handleRatesRefresh(refreshTask, exchangeRates: exchangeRates, currency: currency)
            }
        }
        scheduleRatesRefresh()
    }

    private static func handleRatesRefresh(
        _ task: BGAppRefreshTask,
        exchangeRates: ExchangeRateManager,
        currency: CurrencyStore
    ) async {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        do {
            let base = await currency.selected
            _ = try await exchangeRates.latest(base: base)
            scheduleRatesRefresh()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    static func scheduleRatesRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: ratesRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 21_600) // 6h
        try? BGTaskScheduler.shared.submit(request)
    }
}
