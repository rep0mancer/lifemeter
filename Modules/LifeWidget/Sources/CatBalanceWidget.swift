import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct CatBalanceEntry: TimelineEntry {
    let date: Date
    let currency: String
    let colour: CatColour
}

@available(iOS 17.0, *)
struct CatBalanceProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> CatBalanceEntry {
        CatBalanceEntry(date: Date(), currency: "EUR", colour: .orange)
    }

    func snapshot(for configuration: CurrencySelectionIntent, in _: Context) async -> CatBalanceEntry {
        CatBalanceEntry(date: Date(), currency: configuration.currency.rawValue, colour: .orange)
    }

    func timeline(for configuration: CurrencySelectionIntent, in _: Context) async -> Timeline<CatBalanceEntry> {
        let entry = CatBalanceEntry(date: Date(), currency: configuration.currency.rawValue, colour: .orange)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

@available(iOS 17.0, *)
struct CatBalanceWidgetView: View {
    var entry: CatBalanceEntry

    var body: some View {
        VStack(spacing: 8) {
            Text(entry.currency)
                .font(.headline)
            WidgetCatView(workMinutes: 10, size: 32)
                .tint(entry.colour.color)
        }
    }
}

@available(iOS 17.0, *)
struct CatBalanceWidget: Widget {
    let kind: String = "CatBalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CurrencySelectionIntent.self, provider: CatBalanceProvider()) { entry in
            CatBalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Cat Balance")
        .description("Customise currency and cat colour")
        .supportedFamilies([.systemSmall])
        .contentConfiguration(CatColourIntent())
    }
}
