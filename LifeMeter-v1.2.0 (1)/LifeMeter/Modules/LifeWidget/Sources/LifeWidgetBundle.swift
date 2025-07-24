import WidgetKit
import SwiftUI
import CalcCore
import CatRenderer
import HistoryStore

// MARK: - Widget Bundle
@available(iOS 15.0, *)
@main
struct LifeWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeWidget()
        LifeLockScreenWidget()
    }
}

// MARK: - Main Widget
@available(iOS 15.0, *)
struct LifeWidget: Widget {
    let kind: String = "LifeWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PriceIntent.self, provider: LifeWidgetProvider()) { entry in
            LifeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LifeMeter")
        .description("Convert prices to work time instantly")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget
@available(iOS 16.0, *)
struct LifeLockScreenWidget: Widget {
    let kind: String = "LifeLockScreenWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PriceIntent.self, provider: LifeWidgetProvider()) { entry in
            LifeLockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("LifeMeter Quick")
        .description("Quick price conversion on lock screen")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Provider
@available(iOS 15.0, *)
struct LifeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LifeWidgetEntry {
        LifeWidgetEntry(date: Date(), price: 2.99, workMinutes: 15.0, currency: "EUR")
    }
    
    func snapshot(for configuration: PriceIntent, in context: Context) async -> LifeWidgetEntry {
        let price = configuration.price ?? 2.99
        let workMinutes = calculateWorkTime(for: price)
        let currency = getCurrentCurrency()
        
        return LifeWidgetEntry(date: Date(), price: price, workMinutes: workMinutes, currency: currency)
    }
    
    func timeline(for configuration: PriceIntent, in context: Context) async -> Timeline<LifeWidgetEntry> {
        let price = configuration.price ?? 2.99
        let workMinutes = calculateWorkTime(for: price)
        let currency = getCurrentCurrency()
        
        let entry = LifeWidgetEntry(date: Date(), price: price, workMinutes: workMinutes, currency: currency)
        
        // Update every 15 minutes to keep widget fresh
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        return timeline
    }
    
    private func calculateWorkTime(for price: Double) -> Double {
        guard let hourlyWage = KeychainManager.shared.retrieveWage(), hourlyWage > 0 else {
            return 0
        }
        
        return ConversionEngine.convertToWorkTime(price: price, hourlyWage: hourlyWage)
    }
    
    private func getCurrentCurrency() -> String {
        return KeychainManager.shared.retrieveCurrency()
    }
}

// MARK: - Widget Entry
@available(iOS 15.0, *)
struct LifeWidgetEntry: TimelineEntry {
    let date: Date
    let price: Double
    let workMinutes: Double
    let currency: String
}

// MARK: - Price Intent
@available(iOS 16.0, *)
struct PriceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Price Amount"
    static var description = IntentDescription("The price to convert to work time")
    
    @Parameter(title: "Price", default: 2.99)
    var price: Double?
}

// MARK: - Widget Entry View
@available(iOS 15.0, *)
struct LifeWidgetEntryView: View {
    var entry: LifeWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
@available(iOS 15.0, *)
struct SmallWidgetView: View {
    let entry: LifeWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            // Price display
            Text(CurrencyUtilities.formatPrice(entry.price, currency: entry.currency))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
            
            // Cat animation
            WidgetCatView(workMinutes: entry.workMinutes, size: 32)
            
            // Work time
            Text(ConversionEngine.formatWorkTime(entry.workMinutes))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
                .minimumScaleFactor(0.7)
            
            // Interactive buttons
            if #available(iOS 17.0, *) {
                HStack(spacing: 4) {
                    Button(intent: DecrementPriceIntent()) {
                        Image(systemName: "minus.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: IncrementPriceIntent()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View
@available(iOS 15.0, *)
struct MediumWidgetView: View {
    let entry: LifeWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side - Price and controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Price")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(CurrencyUtilities.formatPrice(entry.price, currency: entry.currency))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if #available(iOS 17.0, *) {
                    HStack(spacing: 8) {
                        Button(intent: DecrementPriceIntent()) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: IncrementPriceIntent()) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Right side - Cat and work time
            VStack(spacing: 8) {
                Text("Work Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                WidgetCatView(workMinutes: entry.workMinutes, size: 48)
                
                Text(ConversionEngine.formatWorkTime(entry.workMinutes))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(ConversionEngine.catState(for: entry.workMinutes).rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Lock Screen Widget View
@available(iOS 16.0, *)
struct LifeLockScreenWidgetView: View {
    let entry: LifeWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(CurrencyUtilities.formatPrice(entry.price, currency: entry.currency)) = \(ConversionEngine.formatWorkTime(entry.workMinutes))")
                .font(.caption)
        case .accessoryCircular:
            VStack(spacing: 2) {
                WidgetCatView(workMinutes: entry.workMinutes, size: 20)
                Text(ConversionEngine.formatWorkTime(entry.workMinutes))
                    .font(.caption2)
                    .minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(CurrencyUtilities.formatPrice(entry.price, currency: entry.currency))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    WidgetCatView(workMinutes: entry.workMinutes, size: 16)
                }
                
                Text("Work time: \(ConversionEngine.formatWorkTime(entry.workMinutes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        default:
            Text("LifeMeter")
        }
    }
}

// MARK: - Interactive Intents
@available(iOS 17.0, *)
struct IncrementPriceIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Price"
    
    func perform() async throws -> some IntentResult {
        // This would increment the price and refresh the widget
        return .result()
    }
}

@available(iOS 17.0, *)
struct DecrementPriceIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrement Price"
    
    func perform() async throws -> some IntentResult {
        // This would decrement the price and refresh the widget
        return .result()
    }
}

// MARK: - Preview
@available(iOS 15.0, *)
struct LifeWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LifeWidgetEntryView(entry: LifeWidgetEntry(date: Date(), price: 2.99, workMinutes: 15.0, currency: "EUR"))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            LifeWidgetEntryView(entry: LifeWidgetEntry(date: Date(), price: 25.50, workMinutes: 85.0, currency: "EUR"))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

