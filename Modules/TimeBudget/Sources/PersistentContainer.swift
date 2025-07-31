import Foundation
import CoreData
import HistoryStore

/// A lightweight wrapper around the app's shared Core Data container.
///
/// The `TimeBudget` module needs access to the same Core Data stack used by
/// the rest of the application.  Rather than creating its own stack,
/// it uses this `PersistentContainer` wrapper to retrieve the shared
/// `NSPersistentContainer` and its main context.  This class mirrors the
/// interface of a typical Core Data container by exposing a `viewContext`
/// property.
public final class PersistentContainer {
    /// Shared singleton instance.
    public static let shared = PersistentContainer()

    /// The main managed object context from the shared Core Data stack.
    public let viewContext: NSManagedObjectContext

    // Private initializer to enforce singleton usage.
    private init() {
        // Reuse the same container provided by `DataController`.
        let container = DataController.shared.container
        self.viewContext = container.viewContext
    }
}
