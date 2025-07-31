import SwiftUI
import Combine
import CalcCore

// MARK: - Wage Entry View
@available(iOS 15.0, *)
public struct WageEntryView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel = WageEntryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    wageInputSection
                    currencySection
                    periodSection
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Enter Your Wage")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("What's your hourly wage?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("This helps LifeMeter convert prices to work time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Wage Input Section
    private var wageInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hourly Wage")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.selectedCurrency.symbol)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("0.00", text: $viewModel.wageText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .onChange(of: viewModel.wageText) { _ in
                            viewModel.validateWageInput()
                        }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.wageValidationState.borderColor, lineWidth: 1)
                )
                
                // Validation Error Message
                if case .invalid(let message) = viewModel.wageValidationState {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.wageValidationState)
    }
    
    // MARK: - Currency Section
    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.supportedCurrencies, id: \.code) { currency in
                        CurrencyButton(
                            currency: currency,
                            isSelected: currency.code == viewModel.selectedCurrency.code
                        ) {
                            viewModel.selectCurrency(currency)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Period Section
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pay Period")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Default Monthly Option (Prominent)
                PeriodButton(
                    period: .monthly,
                    isSelected: viewModel.selectedPeriod == .monthly,
                    isProminent: true
                ) {
                    viewModel.selectPeriod(.monthly)
                }
                
                // Advanced Options (Collapsed by default)
                DisclosureGroup {
                    VStack(spacing: 12) {
                        PeriodButton(
                            period: .hourly,
                            isSelected: viewModel.selectedPeriod == .hourly
                        ) {
                            viewModel.selectPeriod(.hourly)
                        }
                        
                        PeriodButton(
                            period: .daily,
                            isSelected: viewModel.selectedPeriod == .daily
                        ) {
                            viewModel.selectPeriod(.daily)
                        }
                        
                        PeriodButton(
                            period: .weekly,
                            isSelected: viewModel.selectedPeriod == .weekly
                        ) {
                            viewModel.selectPeriod(.weekly)
                        }
                        
                        PeriodButton(
                            period: .yearly,
                            isSelected: viewModel.selectedPeriod == .yearly
                        ) {
                            viewModel.selectPeriod(.yearly)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .font(.caption)
                        Text("Advanced options")
                            .font(.subheadline)
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }
                .accentColor(.secondary)
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: viewModel.saveWage) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    
                    Text("Save Wage")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isConvertButtonEnabled ? .blue : .gray.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.isConvertButtonEnabled || viewModel.isLoading)
            
            Button("Cancel") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Wage Entry View Model
@available(iOS 15.0, *)
public class WageEntryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var wageText: String = ""
    @Published var selectedCurrency: Currency = Currency.defaultCurrency
    @Published var selectedPeriod: PayPeriod = .monthly
    @Published var wageValidationState: ValidationState = .valid
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    // MARK: - Computed Properties
    var supportedCurrencies: [Currency] {
        Currency.supportedCurrencies
    }
    
    var isConvertButtonEnabled: Bool {
        if case .valid = wageValidationState {
            return !isLoading
        }
        return false
    }
    
    // MARK: - Initialization
    public init() {
        setupDefaultCurrency()
    }
    
    // MARK: - Public Methods
    
    public func validateWageInput() {
        guard !wageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            wageValidationState = .invalid("Please enter a valid hourly wage.")
            return
        }
        
        guard let wage = Double(wageText), wage > 0 else {
            if wageText.contains(where: { !$0.isNumber && $0 != "." && $0 != "," }) {
                wageValidationState = .invalid("Please enter a valid number.")
            } else if let wage = Double(wageText), wage <= 0 {
                wageValidationState = .invalid("Wage must be greater than zero.")
            } else {
                wageValidationState = .invalid("Please enter a valid hourly wage.")
            }
            return
        }
        
        // Additional validation for reasonable wage ranges
        if wage > 10000 {
            wageValidationState = .invalid("Wage seems unusually high. Please verify.")
            return
        }
        
        wageValidationState = .valid
    }
    
    public func selectCurrency(_ currency: Currency) {
        guard Currency.supportedCurrencies.contains(where: { $0.code == currency.code }) else {
            showError("Unsupported currency. Please choose a different code.")
            return
        }
        
        selectedCurrency = currency
    }
    
    public func selectPeriod(_ period: PayPeriod) {
        selectedPeriod = period
    }
    
    public func saveWage() {
        validateWageInput()
        
        guard case .valid = wageValidationState else {
            return
        }
        
        guard let wageAmount = Double(wageText) else {
            showError("Invalid wage amount.")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let wage = Wage(
                    amount: wageAmount,
                    currency: selectedCurrency.code,
                    period: selectedPeriod
                )
                
                try KeychainManager.shared.saveWage(wage)
                
                await MainActor.run {
                    isLoading = false
                    // Trigger success flow (e.g., dismiss or navigate)
                    NotificationCenter.default.post(name: .wageDidSave, object: wage)
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError("Failed to save wage: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultCurrency() {
        // Pre-fill currency based on user's locale
        if let localeCode = Locale.current.currencyCode,
           let currency = Currency.supportedCurrencies.first(where: { $0.code == localeCode }) {
            selectedCurrency = currency
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Validation State
public enum ValidationState: Equatable {
    case valid
    case invalid(String)
    
    var borderColor: Color {
        switch self {
        case .valid:
            return .clear
        case .invalid:
            return .red
        }
    }
}

// MARK: - Currency Button
private struct CurrencyButton: View {
    let currency: Currency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(currency.symbol)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text(currency.code)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? .blue : .regularMaterial)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Period Button
private struct PeriodButton: View {
    let period: PayPeriod
    let isSelected: Bool
    let isProminent: Bool
    let action: () -> Void
    
    init(period: PayPeriod, isSelected: Bool, isProminent: Bool = false, action: @escaping () -> Void) {
        self.period = period
        self.isSelected = isSelected
        self.isProminent = isProminent
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(period.displayName)
                            .font(isProminent ? .subheadline : .subheadline)
                            .fontWeight(isProminent ? .semibold : .medium)
                        
                        if isProminent {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(period.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(isProminent ? 16 : 12)
            .background(
                isProminent ? 
                    .regularMaterial : 
                    .thinMaterial, 
                in: RoundedRectangle(cornerRadius: isProminent ? 12 : 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: isProminent ? 12 : 8)
                    .stroke(isSelected ? .blue : .clear, lineWidth: isProminent ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Currency Model
public struct Currency: Codable, Equatable {
    public let code: String
    public let symbol: String
    public let name: String
    
    public init(code: String, symbol: String, name: String) {
        self.code = code
        self.symbol = symbol
        self.name = name
    }
    
    public static let supportedCurrencies: [Currency] = [
        Currency(code: "EUR", symbol: "€", name: "Euro"),
        Currency(code: "USD", symbol: "$", name: "US Dollar"),
        Currency(code: "GBP", symbol: "£", name: "British Pound"),
        Currency(code: "JPY", symbol: "¥", name: "Japanese Yen"),
        Currency(code: "CHF", symbol: "CHF", name: "Swiss Franc"),
        Currency(code: "CAD", symbol: "C$", name: "Canadian Dollar"),
        Currency(code: "AUD", symbol: "A$", name: "Australian Dollar")
    ]
    
    public static let defaultCurrency = supportedCurrencies[0] // EUR
}

// MARK: - Pay Period Model
public enum PayPeriod: String, CaseIterable, Codable {
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    public var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    public var description: String {
        switch self {
        case .hourly: return "Per hour worked"
        case .daily: return "Per 8-hour day"
        case .weekly: return "Per 40-hour week"
        case .monthly: return "Per month (recommended)"
        case .yearly: return "Annual salary"
        }
    }
    
    public var hoursMultiplier: Double {
        switch self {
        case .hourly: return 1.0
        case .daily: return 8.0
        case .weekly: return 40.0
        case .monthly: return 160.0 // ~4 weeks * 40 hours
        case .yearly: return 2080.0 // 52 weeks * 40 hours
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let wageDidSave = Notification.Name("wageDidSave")
}

// MARK: - Preview
@available(iOS 15.0, *)
struct WageEntryView_Previews: PreviewProvider {
    static var previews: some View {
        WageEntryView()
    }
}

