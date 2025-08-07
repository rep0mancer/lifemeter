// swiftlint:disable force_unwrapping
import Foundation

// MARK: - Conversion Engine

public enum ConversionEngine {
    // MARK: - Public Methods

    /// Converts a price to work time in minutes
    /// - Parameters:
    ///   - price: The price to convert
    ///   - hourlyWage: The user's hourly wage
    /// - Returns: Work time in minutes, rounded appropriately
    public static func convertToWorkTime(price: Double, hourlyWage: Double) -> Double {
        guard hourlyWage > 0 else { return 0 }

        let minutes = (price / hourlyWage) * 60.0
        return roundMinutes(minutes)
    }

    /// Converts work time back to price
    /// - Parameters:
    ///   - minutes: Work time in minutes
    ///   - hourlyWage: The user's hourly wage
    /// - Returns: Equivalent price
    public static func convertToPrice(minutes: Double, hourlyWage: Double) -> Double {
        return (minutes / 60.0) * hourlyWage
    }

    /// Formats work time for display
    /// - Parameter minutes: Work time in minutes
    /// - Returns: Formatted string (e.g., "2h 30m", "45m", "1.5m")
    public static func formatWorkTime(_ minutes: Double) -> String {
        if minutes < 1.0 {
            return String(format: "%.1fm", minutes)
        } else if minutes < 60.0 {
            return String(format: "%.0fm", minutes)
        } else {
            let hours = Int(minutes / 60)
            let remainingMinutes = Int(minutes.truncatingRemainder(dividingBy: 60))

            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    /// Determines cat animation state based on work time
    /// - Parameter minutes: Work time in minutes
    /// - Returns: Cat animation state
    public static func catState(for minutes: Double) -> CatState {
        switch minutes {
        case 0 ..< 5:
            return .pounce
        case 5 ..< 30:
            return .run
        case 30 ..< 120:
            return .walk
        default:
            return .sleep
        }
    }

    // MARK: - Private Methods

    private static func roundMinutes(_ minutes: Double) -> Double {
        if minutes < 60.0 {
            // Round to nearest 0.1 minute for values < 1 hour
            return round(minutes * 10) / 10
        } else {
            // Round to nearest minute for values >= 1 hour
            return round(minutes)
        }
    }
}

// MARK: - Cat Animation States

public enum CatState: String, CaseIterable {
    case sleep
    case walk
    case run
    case pounce

    public var frameRate: Double {
        switch self {
        case .sleep: return 2.0
        case .walk: return 4.0
        case .run: return 6.0
        case .pounce: return 8.0
        }
    }

    public var description: String {
        switch self {
        case .sleep: return "Cat curled up, eyes shut"
        case .walk: return "Cat strolling"
        case .run: return "Cat trotting fast"
        case .pounce: return "Cat jumping & meowing"
        }
    }

    public var threshold: String {
        switch self {
        case .sleep: return "≥ 120 min"
        case .walk: return "30 – 119 min"
        case .run: return "5 – 29 min"
        case .pounce: return "< 5 min"
        }
    }
}

// MARK: - Currency Utilities

public enum CurrencyUtilities {
    /// Supported currencies with their symbols
    public static let supportedCurrencies: [String: String] = [
        "EUR": "€",
        "USD": "$",
        "GBP": "£",
        "JPY": "¥",
        "CHF": "CHF",
        "CAD": "C$",
        "AUD": "A$",
    ]

    public static let supportedCurrencyCodes: Set<String> = Set(supportedCurrencies.keys)

    /// Gets currency symbol for identifier
    /// - Parameter identifier: Currency identifier (e.g., "EUR")
    /// - Returns: Currency symbol (e.g., "€")
    public static func symbol(for identifier: String) -> String {
        return supportedCurrencies[identifier] ?? identifier
    }

    /// Formats price with currency
    /// - Parameters:
    ///   - price: Price to format
    ///   - currency: Currency identifier
    ///   - locale: Locale for formatting
    /// - Returns: Formatted price string
    public static func formatPrice(_ price: Double, currency: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = locale

        return formatter.string(from: NSNumber(value: price)) ?? "\(symbol(for: currency))\(price)"
    }

    /// Parses price from text using regex
    /// - Parameter text: Text containing price
    /// - Returns: Tuple of (price, currency) if found
    public static func parsePrice(from text: String) -> (price: Double, currency: String)? {
        let patterns = [
            // Symbol before number: €12.99, $25.50
            #"([€$£¥])\s?([0-9,]+\.?[0-9]*)"#,
            // Number before currency code: 12.99 EUR, 25.50 USD
            #"([0-9,]+\.?[0-9]*)\s?(EUR|USD|GBP|JPY|CHF|CAD|AUD)"#,
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])

                // Extract price and currency
                if let result = extractPriceAndCurrency(from: matchedText, pattern: pattern) {
                    return result
                }
            }
        }

        return nil
    }

    private static func extractPriceAndCurrency(from text: String, pattern: String) -> (price: Double, currency: String)? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)

        guard let match = regex?.firstMatch(in: text, range: range) else { return nil }

        let groups = (0 ..< match.numberOfRanges).compactMap { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return nil }
            return String(text[Range(range, in: text)!])
        }

        guard groups.count >= 3 else { return nil }

        // Determine if symbol comes first or last
        let first = groups[1]
        let second = groups[2]

        let (priceString, currencyString): (String, String)

        if first.contains(where: { "€$£¥".contains($0) }) {
            // Symbol first pattern
            currencyString = first
            priceString = second
        } else {
            // Currency code last pattern
            priceString = first
            currencyString = second
        }

        // Clean and parse price
        let cleanPriceString = priceString.replacingOccurrences(of: ",", with: "")
        guard let price = Double(cleanPriceString) else { return nil }

        // Convert symbol to currency code
        let currency = currencyCode(from: currencyString)

        return (price: price, currency: currency)
    }

    private static func currencyCode(from symbol: String) -> String {
        switch symbol {
        case "€": return "EUR"
        case "$": return "USD"
        case "£": return "GBP"
        case "¥": return "JPY"
        default: return symbol
        }
    }
}
