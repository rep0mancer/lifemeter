import Foundation

/// A simple wage structure used by tests and higher-level modules.
///
/// This struct provides a lightweight representation of a user's wage, including
/// the amount, currency, and pay period. It mirrors the structure of
/// ``WageData`` defined in ``HardenedKeychainManager`` but is defined here
/// outside of the hardened keychain layer so that other modules and tests can
/// depend on a plain Swift type without importing the hardened keychain code.
///
/// The ``PayPeriod`` enum matches the cases provided by the core data model,
/// supporting hourly, daily, weekly, monthly and yearly wages. When adding
/// new cases here, be sure to update ``WageData`` and any conversion logic
/// accordingly.
public struct Wage: Equatable, Codable {
    /// The wage amount.
    public var amount: Double
    /// The ISO currency code for the wage.
    public var currency: String
    /// The pay period for which the wage is specified.
    public var period: PayPeriod

    /// Creates a new ``Wage``.
    ///
    /// - Parameters:
    ///   - amount: The wage amount.
    ///   - currency: The ISO currency code.
    ///   - period: The pay period for the wage.
    public init(amount: Double, currency: String, period: PayPeriod) {
        self.amount = amount
        self.currency = currency
        self.period = period
    }
}

/// The period over which a wage is paid.
///
/// Mirrors the ``PayPeriod`` enum defined in ``HardenedKeychainManager``.
public enum PayPeriod: String, Codable {
    case hourly
    case daily
    case weekly
    case monthly
    case yearly
}
