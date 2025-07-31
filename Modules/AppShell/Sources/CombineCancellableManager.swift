import Combine
import Foundation

// MARK: - Combine Cancellable Manager

public class CombineCancellableManager {
    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.lifemeter.cancellables", attributes: .concurrent)

    // MARK: - Public Methods

    /// Store a cancellable
    public func store(_ cancellable: AnyCancellable) {
        queue.async(flags: .barrier) {
            cancellable.store(in: &self.cancellables)
        }
    }

    /// Store multiple cancellables
    public func store(_ cancellables: [AnyCancellable]) {
        queue.async(flags: .barrier) {
            for cancellable in cancellables {
                cancellable.store(in: &self.cancellables)
            }
        }
    }

    /// Cancel all stored cancellables
    public func cancelAll() {
        queue.async(flags: .barrier) {
            self.cancellables.forEach { $0.cancel() }
            self.cancellables.removeAll()
        }
    }

    /// Get count of active cancellables
    public var activeCancellablesCount: Int {
        return queue.sync {
            cancellables.count
        }
    }

    /// Check if there are any active cancellables
    public var hasActiveCancellables: Bool {
        return activeCancellablesCount > 0
    }

    /// Remove completed cancellables (those that have already finished)
    public func removeCompletedCancellables() {
        queue.async(flags: .barrier) {
            // Note: AnyCancellable doesn't provide a way to check if it's completed
            // This method is here for future enhancement if needed
            // For now, we rely on automatic cleanup when publishers complete
        }
    }
}

// MARK: - Cancellable Storage Protocol

public protocol CancellableStorage: AnyObject {
    var cancellableManager: CombineCancellableManager { get }
}

// MARK: - Default Implementation

public extension CancellableStorage {
    /// Store a cancellable using the manager
    func store(_ cancellable: AnyCancellable) {
        cancellableManager.store(cancellable)
    }

    /// Store multiple cancellables using the manager
    func store(_ cancellables: [AnyCancellable]) {
        cancellableManager.store(cancellables)
    }

    /// Cancel all cancellables
    func cancelAllSubscriptions() {
        cancellableManager.cancelAll()
    }
}

// MARK: - Enhanced View Model Base

@available(iOS 15.0, *)
open class BaseViewModel: ObservableObject, CancellableStorage {
    // MARK: - Properties

    public let cancellableManager = CombineCancellableManager()

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    deinit {
        cancellableManager.cancelAll()

        #if DEBUG
            print("🗑️ \(String(describing: type(of: self))) deinitialized, cancelled \(cancellableManager.activeCancellablesCount) subscriptions")
        #endif
    }
}

// MARK: - Enhanced View Controller Base

@available(iOS 15.0, *)
open class BaseViewController: UIViewController, CancellableStorage {
    // MARK: - Properties

    public let cancellableManager = CombineCancellableManager()

    // MARK: - Lifecycle

    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Cancel subscriptions when view disappears to prevent memory leaks
        if isBeingDismissed || isMovingFromParent {
            cancellableManager.cancelAll()
        }
    }

    deinit {
        cancellableManager.cancelAll()

        #if DEBUG
            print("🗑️ \(String(describing: type(of: self))) deinitialized, cancelled \(cancellableManager.activeCancellablesCount) subscriptions")
        #endif
    }
}

// MARK: - Subscription Tracker

public class SubscriptionTracker {
    // MARK: - Singleton

    public static let shared = SubscriptionTracker()

    // MARK: - Properties

    private var activeSubscriptions: [String: Int] = [:]
    private let queue = DispatchQueue(label: "com.lifemeter.subscription-tracker", attributes: .concurrent)

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Register a new subscription
    public func registerSubscription(for owner: String) {
        queue.async(flags: .barrier) {
            self.activeSubscriptions[owner, default: 0] += 1
        }
    }

    /// Unregister a subscription
    public func unregisterSubscription(for owner: String) {
        queue.async(flags: .barrier) {
            if let count = self.activeSubscriptions[owner], count > 0 {
                self.activeSubscriptions[owner] = count - 1
                if self.activeSubscriptions[owner] == 0 {
                    self.activeSubscriptions.removeValue(forKey: owner)
                }
            }
        }
    }

    /// Get subscription count for owner
    public func getSubscriptionCount(for owner: String) -> Int {
        return queue.sync {
            activeSubscriptions[owner] ?? 0
        }
    }

    /// Get all active subscriptions
    public func getAllActiveSubscriptions() -> [String: Int] {
        return queue.sync {
            activeSubscriptions
        }
    }

    /// Get total subscription count
    public var totalActiveSubscriptions: Int {
        return queue.sync {
            activeSubscriptions.values.reduce(0, +)
        }
    }

    /// Print subscription report
    public func printSubscriptionReport() {
        let subscriptions = getAllActiveSubscriptions()

        print("📊 Active Subscriptions Report:")
        print("Total: \(totalActiveSubscriptions)")

        for (owner, count) in subscriptions.sorted(by: { $0.value > $1.value }) {
            print("  \(owner): \(count)")
        }
    }
}

// MARK: - Tracked Cancellable

public class TrackedCancellable: Cancellable {
    private let cancellable: AnyCancellable
    private let owner: String

    public init(_ cancellable: AnyCancellable, owner: String) {
        self.cancellable = cancellable
        self.owner = owner

        SubscriptionTracker.shared.registerSubscription(for: owner)
    }

    public func cancel() {
        cancellable.cancel()
        SubscriptionTracker.shared.unregisterSubscription(for: owner)
    }

    deinit {
        SubscriptionTracker.shared.unregisterSubscription(for: owner)
    }
}

// MARK: - Publisher Extensions

public extension Publisher {
    /// Store cancellable with automatic cleanup tracking
    func store<T: CancellableStorage>(in storage: T, owner: String? = nil) -> AnyCancellable {
        let ownerName = owner ?? String(describing: type(of: storage))
        let cancellable = sink(
            receiveCompletion: { _ in
                SubscriptionTracker.shared.unregisterSubscription(for: ownerName)
            },
            receiveValue: { _ in }
        )

        let trackedCancellable = TrackedCancellable(cancellable, owner: ownerName)
        storage.cancellableManager.store(AnyCancellable(trackedCancellable))

        return AnyCancellable(trackedCancellable)
    }

    /// Store cancellable with automatic cleanup and custom completion handling
    func store<T: CancellableStorage>(
        in storage: T,
        owner: String? = nil,
        receiveCompletion: @escaping (Subscribers.Completion<Self.Failure>) -> Void = { _ in },
        receiveValue: @escaping (Self.Output) -> Void
    ) -> AnyCancellable {
        let ownerName = owner ?? String(describing: type(of: storage))
        let cancellable = sink(
            receiveCompletion: { completion in
                receiveCompletion(completion)
                SubscriptionTracker.shared.unregisterSubscription(for: ownerName)
            },
            receiveValue: receiveValue
        )

        let trackedCancellable = TrackedCancellable(cancellable, owner: ownerName)
        storage.cancellableManager.store(AnyCancellable(trackedCancellable))

        return AnyCancellable(trackedCancellable)
    }
}

// MARK: - Memory Leak Detector

public class MemoryLeakDetector {
    // MARK: - Singleton

    public static let shared = MemoryLeakDetector()

    // MARK: - Properties

    private var checkTimer: Timer?
    private let checkInterval: TimeInterval = 30.0 // Check every 30 seconds

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start monitoring for memory leaks
    public func startMonitoring() {
        stopMonitoring() // Stop any existing monitoring

        checkTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            self.performLeakCheck()
        }
    }

    /// Stop monitoring
    public func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    /// Perform immediate leak check
    public func performLeakCheck() {
        let totalSubscriptions = SubscriptionTracker.shared.totalActiveSubscriptions

        #if DEBUG
            if totalSubscriptions > 50 { // Threshold for potential leak
                print("⚠️ Potential memory leak detected: \(totalSubscriptions) active subscriptions")
                SubscriptionTracker.shared.printSubscriptionReport()
            }
        #endif
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Automatic Cleanup Mixin

public protocol AutomaticCleanup: AnyObject {
    func setupAutomaticCleanup()
}

public extension AutomaticCleanup where Self: CancellableStorage {
    func setupAutomaticCleanup() {
        // Set up automatic cleanup based on app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .store(in: self, owner: "AutomaticCleanup") { _ in
                // Cancel non-essential subscriptions when app goes to background
                self.cancelAllSubscriptions()
            }

        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .store(in: self, owner: "AutomaticCleanup") { _ in
                // Cancel all subscriptions on memory warning
                self.cancelAllSubscriptions()
            }
    }
}

// MARK: - Usage Examples and Best Practices

/*
 MARK: - Usage Examples

 // 1. Using BaseViewModel
 class MyViewModel: BaseViewModel {

     override init() {
         super.init()
         setupSubscriptions()
     }

     private func setupSubscriptions() {
         // Subscriptions are automatically cleaned up on deinit
         somePublisher
             .store(in: self) { value in
                 // Handle value
             }
     }
 }

 // 2. Using BaseViewController
 class MyViewController: BaseViewController {

     override func viewDidLoad() {
         super.viewDidLoad()
         setupSubscriptions()
     }

     private func setupSubscriptions() {
         // Subscriptions are automatically cleaned up when view is dismissed
         somePublisher
             .store(in: self) { value in
                 // Handle value
             }
     }
 }

 // 3. Manual cancellable management
 class MyClass: CancellableStorage {
     let cancellableManager = CombineCancellableManager()

     func setupSubscriptions() {
         somePublisher
             .sink { value in
                 // Handle value
             }
             .store(in: &cancellables) // Old way

         // New way with automatic tracking
         somePublisher
             .store(in: self) { value in
                 // Handle value
             }
     }

     deinit {
         cancelAllSubscriptions()
     }
 }

 // 4. Memory leak monitoring
 class AppDelegate: UIApplicationDelegate {

     func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

         #if DEBUG
         MemoryLeakDetector.shared.startMonitoring()
         #endif

         return true
     }
 }
 */
