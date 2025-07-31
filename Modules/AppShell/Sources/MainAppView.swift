import CalcCore
import CatRenderer
import HistoryStore
import PriceCapture

// swiftlint:disable force_unwrapping
import SwiftUI
import WageOnboarding

// MARK: - Main App View

@available(iOS 15.0, *)
public struct MainAppView: View {
    @StateObject private var viewModel = MainAppViewModel()
    @State private var showingPriceCapture = false
    @State private var showingSettings = false
    @State private var showingHistory = false

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                // Glass-morphism background
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.needsOnboarding {
                    WageOnboardingView()
                } else {
                    mainContentView
                }
            }
        }
        .onAppear {
            viewModel.checkOnboardingStatus()
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 32) {
            headerSection
            quickCalculationSection
            catDisplaySection
            actionButtonsSection

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPriceCapture) {
            PriceCaptureView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LifeMeter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Time is money")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }

    private var quickCalculationSection: some View {
        VStack(spacing: 16) {
            Text("Quick Calculate")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                TextField("Enter price", text: $viewModel.quickPriceInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )

                Text(viewModel.currencySymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }

            if viewModel.isValidQuickPrice {
                VStack(spacing: 8) {
                    Text("Work time:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.formattedQuickWorkTime)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isValidQuickPrice)
    }

    private var catDisplaySection: some View {
        VStack(spacing: 16) {
            Text("Your effort level")
                .font(.headline)
                .fontWeight(.semibold)

            CatStateIndicator(
                workMinutes: viewModel.quickWorkTime,
                showDetails: true
            )

            Text(ConversionEngine.catState(for: viewModel.quickWorkTime).threshold)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary action button
            Button(action: {
                showingPriceCapture = true
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)

                    Text("Scan or Enter Price")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.blue)
                )
            }

            // Secondary actions
            HStack(spacing: 16) {
                Button(action: {
                    showingHistory = true
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                }

                Button(action: {
                    viewModel.saveQuickCalculation()
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Save")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.isValidQuickPrice ? .green : .gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                }
                .disabled(!viewModel.isValidQuickPrice)
            }
        }
    }
}

// MARK: - Settings View

@available(iOS 15.0, *)
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Wage Settings") {
                    HStack {
                        Text("Hourly Wage")
                        Spacer()
                        TextField("0.00", text: $viewModel.wageInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Currency")
                        Spacer()
                        Picker("Currency", selection: $viewModel.selectedCurrency) {
                            ForEach(Array(CurrencyUtilities.supportedCurrencies.keys.sorted()), id: \.self) { currency in
                                Text("\(CurrencyUtilities.symbol(for: currency)) \(currency)")
                                    .tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Data & Privacy") {
                    Toggle("iCloud Sync", isOn: $viewModel.cloudSyncEnabled)

                    Button("Clear All Data") {
                        viewModel.showingClearDataAlert = true
                    }
                    .foregroundColor(.red)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://lifemeter.app/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://lifemeter.app/terms")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
            .alert("Clear All Data", isPresented: $viewModel.showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("This will permanently delete all your calculations and settings. This action cannot be undone.")
            }
        }
    }
}

// MARK: - History View

@available(iOS 15.0, *)
struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.calculations) { calculation in
                    HistoryRowView(calculation: calculation)
                }
                .onDelete(perform: viewModel.deleteCalculations)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadCalculations()
            }
        }
    }
}

// MARK: - History Row View

@available(iOS 15.0, *)
struct HistoryRowView: View {
    let calculation: Calculation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(CurrencyUtilities.formatPrice(calculation.price, currency: calculation.currency))
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(calculation.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ConversionEngine.formatWorkTime(calculation.minutes))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                WidgetCatView(workMinutes: calculation.minutes, size: 24)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
