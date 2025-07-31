import CalcCore
import HistoryStore
import SwiftUI

// MARK: - Wage Onboarding View

@available(iOS 15.0, *)
public struct WageOnboardingView: View {
    @StateObject private var viewModel = WageOnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                // Glass-morphism background
                Color.black.opacity(0.1)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    headerSection
                    wageInputSection
                    periodSelectionSection
                    currencySelectionSection
                    continueButton

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $viewModel.showThankYouModal) {
            ThankYouModalView(workMinutes: viewModel.appCostWorkTime)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("Welcome to LifeMeter")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Convert any price into the time you work to afford it")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var wageInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your take-home wage")
                .font(.headline)
                .fontWeight(.semibold)

            HStack {
                TextField("0", text: $viewModel.wageInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )

                Text(viewModel.selectedCurrency)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
        }
    }

    private var periodSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pay period")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                ForEach(PayPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        viewModel.selectedPeriod = period
                    }) {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.selectedPeriod == period ? .blue : .regularMaterial)
                            )
                            .foregroundColor(viewModel.selectedPeriod == period ? .white : .primary)
                    }
                }
            }
        }
    }

    private var currencySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currency")
                .font(.headline)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(CurrencyUtilities.supportedCurrencies.keys.sorted()), id: \.self) { currency in
                        Button(action: {
                            viewModel.selectedCurrency = currency
                        }) {
                            HStack {
                                Text(CurrencyUtilities.symbol(for: currency))
                                Text(currency)
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.selectedCurrency == currency ? .blue : .regularMaterial)
                            )
                            .foregroundColor(viewModel.selectedCurrency == currency ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var continueButton: some View {
        Button(action: {
            viewModel.saveWageAndShowThankYou()
        }) {
            Text("Continue")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.isValidInput ? .blue : .gray)
                )
        }
        .disabled(!viewModel.isValidInput)
    }
}

// MARK: - Thank You Modal

@available(iOS 15.0, *)
struct ThankYouModalView: View {
    let workMinutes: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            VStack(spacing: 16) {
                Text("Thank You!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("You worked")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text(ConversionEngine.formatWorkTime(workMinutes))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                Text("to own LifeMeter")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Text("Start Using LifeMeter")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.blue)
                    )
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
        .background(.regularMaterial)
    }
}

// MARK: - Pay Period Enum

public enum PayPeriod: String, CaseIterable {
    case hourly
    case daily
    case monthly
    case yearly

    public var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .daily: return "Daily"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    public var hoursMultiplier: Double {
        switch self {
        case .hourly: return 1.0
        case .daily: return 8.0 // Assuming 8-hour workday
        case .monthly: return 160.0 // Assuming 20 working days * 8 hours
        case .yearly: return 2080.0 // Assuming 52 weeks * 40 hours
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct WageOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        WageOnboardingView()
    }
}
