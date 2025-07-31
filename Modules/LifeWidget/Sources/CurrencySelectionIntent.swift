import AppIntents
import CalcCore

@available(iOS 17.0, *)
public enum CurrencyOption: String, CaseIterable, AppEnum {
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case chf = "CHF"

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Currency")

    public static var caseDisplayRepresentations: [CurrencyOption: DisplayRepresentation] = [
        .eur: DisplayRepresentation(title: "EUR"),
        .usd: DisplayRepresentation(title: "USD"),
        .gbp: DisplayRepresentation(title: "GBP"),
        .jpy: DisplayRepresentation(title: "JPY"),
        .cad: DisplayRepresentation(title: "CAD"),
        .aud: DisplayRepresentation(title: "AUD"),
        .chf: DisplayRepresentation(title: "CHF")
    ]
}

@available(iOS 17.0, *)
public struct CurrencySelectionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Currency"

    @Parameter(title: "Currency")
    public var currency: CurrencyOption

    public init() {}

    public init(currency: CurrencyOption) {
        self.currency = currency
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Currency: \(\.$currency)")
    }

    public func perform() async throws -> some IntentResult {
        await CurrencyManager.shared.setCurrency(currency.rawValue)
        return .result()
    }
}
