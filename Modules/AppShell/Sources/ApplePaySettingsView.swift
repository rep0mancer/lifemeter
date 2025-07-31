import SwiftUI
import TransactionLogger

// MARK: - Apple Pay Settings View
@available(iOS 17.0, *)
public struct ApplePaySettingsView: View {
    
    // MARK: - Properties
    @State private var isAutomationEnabled = false
    @State private var showingSetup = false
    @State private var showingHistory = false
    @State private var recentTransactions: [Calculation] = []
    
    // MARK: - Body
    public var body: some View {
        List {
            automationSection
            historySection
            informationSection
        }
        .navigationTitle("Apple Pay")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            checkAutomationStatus()
            loadRecentTransactions()
        }
        .sheet(isPresented: $showingSetup) {
            ApplePaySetupView()
        }
        .sheet(isPresented: $showingHistory) {
            ApplePayHistoryView()
        }
    }
    
    // MARK: - Automation Section
    private var automationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Pay Automation")
                            .font(.headline)
                        
                        Text(isAutomationEnabled ? "Active" : "Not configured")
                            .font(.caption)
                            .foregroundColor(isAutomationEnabled ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isAutomationEnabled)
                        .disabled(true) // Read-only, managed through Shortcuts
                }
                
                if !isAutomationEnabled {
                    Button(action: { showingSetup = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Automation")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Automation")
        } footer: {
            if isAutomationEnabled {
                Text("Automation is active. Apple Pay transactions will automatically appear in LifeMeter.")
            } else {
                Text("Set up automation to automatically track Apple Pay purchases.")
            }
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        Section {
            if recentTransactions.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    
                    Text("No Apple Pay transactions yet")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(recentTransactions.prefix(3), id: \.id) { transaction in
                    ApplePayTransactionRow(transaction: transaction)
                }
                
                if recentTransactions.count > 3 {
                    Button("View All Apple Pay Transactions") {
                        showingHistory = true
                    }
                    .foregroundColor(.blue)
                }
            }
        } header: {
            Text("Recent Transactions")
        } footer: {
            if !recentTransactions.isEmpty {
                Text("Showing your most recent Apple Pay transactions.")
            }
        }
    }
    
    // MARK: - Information Section
    private var informationSection: some View {
        Section {
            InfoRow(
                icon: "iphone.radiowaves.left.and.right",
                title: "NFC Payments",
                description: "Works with tap-to-pay at terminals",
                status: "Supported"
            )
            
            InfoRow(
                icon: "applewatch",
                title: "Apple Watch",
                description: "Watch payments not currently supported",
                status: "Coming Soon"
            )
            
            InfoRow(
                icon: "apps.iphone",
                title: "In-App Purchases",
                description: "App Store purchases not reported by iOS",
                status: "Not Available"
            )
            
            InfoRow(
                icon: "lock.shield",
                title: "Privacy",
                description: "All data stays on your device",
                status: "Protected"
            )
        } header: {
            Text("Information")
        } footer: {
            Text("Apple Pay automation uses iOS Shortcuts and respects your privacy. No transaction data is sent to external servers.")
        }
    }
    
    // MARK: - Helper Methods
    private func checkAutomationStatus() {
        // Check if the shortcut automation exists
        // This would typically query the Shortcuts app or check UserDefaults
        // For now, we'll simulate the check
        isAutomationEnabled = UserDefaults.standard.bool(forKey: "ApplePayAutomationEnabled")
    }
    
    private func loadRecentTransactions() {
        // Load recent Apple Pay transactions from HistoryStore
        // This would filter for source == .applePay
        // For now, we'll use sample data
        recentTransactions = []
    }
}

// MARK: - Apple Pay Transaction Row
@available(iOS 17.0, *)
private struct ApplePayTransactionRow: View {
    let transaction: Calculation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(transaction.merchant ?? "Apple Pay Purchase")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(CurrencyUtilities.formatPrice(transaction.price, currency: transaction.currency))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text(transaction.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(ConversionEngine.formatWorkTime(transaction.minutes))
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Info Row
private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 2)
    }
    
    private var statusColor: Color {
        switch status {
        case "Supported", "Protected":
            return .green
        case "Coming Soon":
            return .orange
        case "Not Available":
            return .secondary
        default:
            return .primary
        }
    }
}

// MARK: - Apple Pay History View
@available(iOS 17.0, *)
private struct ApplePayHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [Calculation] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(transactions, id: \.id) { transaction in
                    ApplePayTransactionRow(transaction: transaction)
                }
            }
            .navigationTitle("Apple Pay History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAllTransactions()
        }
    }
    
    private func loadAllTransactions() {
        // Load all Apple Pay transactions from HistoryStore
        transactions = []
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
struct ApplePaySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ApplePaySettingsView()
        }
    }
}

