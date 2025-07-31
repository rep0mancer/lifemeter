import SwiftUI
import TransactionLogger

// MARK: - Apple Pay Setup View

@available(iOS 17.0, *)
public struct ApplePaySetupView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingShortcuts = false
    @State private var setupStatus: SetupStatus = .notStarted
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Setup Status

    private enum SetupStatus {
        case notStarted
        case inProgress
        case completed
        case failed
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    benefitsSection
                    setupInstructionsSection
                    actionButtonsSection
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Apple Pay Automation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .alert("Setup Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Apple Pay Icon
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 80, height: 80)

                Image(systemName: "applelogo")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 8) {
                Text("Set up Apple Pay Automation")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Automatically track your Apple Pay purchases")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What you'll get:")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                BenefitRow(
                    icon: "bolt.fill",
                    title: "Instant Calculations",
                    description: "See work time immediately after each Apple Pay purchase"
                )

                BenefitRow(
                    icon: "bell.fill",
                    title: "Smart Notifications",
                    description: "Get notified with \"€4.50 coffee • 9m 12s\" right after paying"
                )

                BenefitRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Protected",
                    description: "All processing happens on your device - no data leaves your iPhone"
                )

                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Automatic History",
                    description: "Apple Pay purchases are automatically saved to your LifeMeter history"
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Setup Instructions

    private var setupInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works:")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                InstructionStep(
                    number: 1,
                    title: "Tap \"Add Automation\"",
                    description: "We'll open the Shortcuts app with a pre-configured automation"
                )

                InstructionStep(
                    number: 2,
                    title: "Accept the automation",
                    description: "Make sure \"Ask Before Running\" is turned OFF for seamless operation"
                )

                InstructionStep(
                    number: 3,
                    title: "Start using Apple Pay",
                    description: "Next time you tap to pay, LifeMeter will automatically show your work time"
                )
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: setupApplePayAutomation) {
                HStack {
                    if setupStatus == .inProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }

                    Text(buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(buttonColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(setupStatus == .inProgress)

            // Secondary action button
            Button("Maybe Later") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Works for NFC 'tap to pay' on iPhone")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("In-app and Watch purchases currently not reported by iOS")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        switch setupStatus {
        case .notStarted:
            return "Add Automation"
        case .inProgress:
            return "Setting up..."
        case .completed:
            return "Setup Complete"
        case .failed:
            return "Try Again"
        }
    }

    private var buttonColor: Color {
        switch setupStatus {
        case .notStarted, .failed:
            return .blue
        case .inProgress:
            return .blue.opacity(0.7)
        case .completed:
            return .green
        }
    }

    // MARK: - Actions

    private func setupApplePayAutomation() {
        setupStatus = .inProgress

        Task {
            do {
                // Generate the shortcut import URL
                guard let importURL = ShortcutTemplate.shared.generateImportURL() else {
                    throw SetupError.failedToGenerateShortcut
                }

                // Open Shortcuts app with the automation
                await MainActor.run {
                    UIApplication.shared.open(importURL) { success in
                        if success {
                            setupStatus = .completed

                            // Dismiss after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        } else {
                            setupStatus = .failed
                            errorMessage = "Failed to open Shortcuts app. Please try again."
                            showingError = true
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    setupStatus = .failed
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Instruction Step

private struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Setup Error

private enum SetupError: LocalizedError {
    case failedToGenerateShortcut
    case shortcutsAppNotAvailable

    var errorDescription: String? {
        switch self {
        case .failedToGenerateShortcut:
            return "Failed to generate the automation shortcut. Please try again."
        case .shortcutsAppNotAvailable:
            return "Shortcuts app is not available on this device."
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct ApplePaySetupView_Previews: PreviewProvider {
    static var previews: some View {
        ApplePaySetupView()
    }
}
