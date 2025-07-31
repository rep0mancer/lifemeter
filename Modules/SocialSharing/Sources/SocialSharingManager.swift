import Foundation
import SwiftUI
import UIKit

// MARK: - Social Sharing Manager

@available(iOS 15.0, *)
public class SocialSharingManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = SocialSharingManager()

    // MARK: - Properties

    private let cardGenerator = SharingCardGenerator()
    private let templateManager = SharingTemplateManager()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Generate and share a calculation result
    public func shareCalculation(
        price: Double,
        currency: String,
        workTime: String,
        template: SharingTemplate = .modern,
        from viewController: UIViewController
    ) {
        Task {
            do {
                let card = try await generateCalculationCard(
                    price: price,
                    currency: currency,
                    workTime: workTime,
                    template: template
                )

                await MainActor.run {
                    self.presentShareSheet(with: card, from: viewController)
                }
            } catch {
                await MainActor.run {
                    self.showError(error, from: viewController)
                }
            }
        }
    }

    /// Generate and share budget summary
    public func shareBudgetSummary(
        _ summary: BudgetSummary,
        budgetName: String,
        template: SharingTemplate = .budget,
        from viewController: UIViewController
    ) {
        Task {
            do {
                let card = try await generateBudgetCard(
                    summary: summary,
                    budgetName: budgetName,
                    template: template
                )

                await MainActor.run {
                    self.presentShareSheet(with: card, from: viewController)
                }
            } catch {
                await MainActor.run {
                    self.showError(error, from: viewController)
                }
            }
        }
    }

    /// Generate and share time awareness message
    public func shareTimeAwareness(
        totalCalculations: Int,
        totalWorkTime: String,
        template: SharingTemplate = .awareness,
        from viewController: UIViewController
    ) {
        Task {
            do {
                let card = try await generateAwarenessCard(
                    totalCalculations: totalCalculations,
                    totalWorkTime: totalWorkTime,
                    template: template
                )

                await MainActor.run {
                    self.presentShareSheet(with: card, from: viewController)
                }
            } catch {
                await MainActor.run {
                    self.showError(error, from: viewController)
                }
            }
        }
    }

    /// Get available sharing templates
    public func getAvailableTemplates() -> [SharingTemplate] {
        return SharingTemplate.allCases
    }

    /// Preview a sharing card without sharing
    public func previewCard(
        price: Double,
        currency: String,
        workTime: String,
        template: SharingTemplate
    ) async throws -> UIImage {
        return try await generateCalculationCard(
            price: price,
            currency: currency,
            workTime: workTime,
            template: template
        )
    }

    // MARK: - Private Methods

    private func generateCalculationCard(
        price: Double,
        currency: String,
        workTime: String,
        template: SharingTemplate
    ) async throws -> UIImage {
        let cardView = CalculationSharingCard(
            price: price,
            currency: currency,
            workTime: workTime,
            template: template
        )

        return try await cardGenerator.generateImage(from: cardView)
    }

    private func generateBudgetCard(
        summary: BudgetSummary,
        budgetName: String,
        template: SharingTemplate
    ) async throws -> UIImage {
        let cardView = BudgetSharingCard(
            summary: summary,
            budgetName: budgetName,
            template: template
        )

        return try await cardGenerator.generateImage(from: cardView)
    }

    private func generateAwarenessCard(
        totalCalculations: Int,
        totalWorkTime: String,
        template: SharingTemplate
    ) async throws -> UIImage {
        let cardView = AwarenessSharingCard(
            totalCalculations: totalCalculations,
            totalWorkTime: totalWorkTime,
            template: template
        )

        return try await cardGenerator.generateImage(from: cardView)
    }

    private func presentShareSheet(with image: UIImage, from viewController: UIViewController) {
        let text = generateShareText()
        let items: [Any] = [text, image]

        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Exclude certain activity types for privacy
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .postToVimeo,
            .postToFlickr,
        ]

        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(activityViewController, animated: true)
    }

    private func generateShareText() -> String {
        return "Check out how much work time this purchase costs with LifeMeter! 💰⏰ #LifeMeter #TimeAwareness #FinancialWisdom"
    }

    private func showError(_ error: Error, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Sharing Failed",
            message: "Unable to generate sharing card: \(error.localizedDescription)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
}

// MARK: - Sharing Card Generator

@available(iOS 15.0, *)
public class SharingCardGenerator {
    public init() {}

    /// Generate UIImage from SwiftUI view
    public func generateImage<Content: View>(from view: Content) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let hostingController = UIHostingController(rootView: view)

                // Set fixed size for sharing cards
                let cardSize = CGSize(width: 400, height: 600)
                hostingController.view.frame = CGRect(origin: .zero, size: cardSize)

                // Force layout
                hostingController.view.layoutIfNeeded()

                // Generate image
                let renderer = UIGraphicsImageRenderer(size: cardSize)
                let image = renderer.image { context in
                    hostingController.view.layer.render(in: context.cgContext)
                }

                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Sharing Template Manager

public class SharingTemplateManager {
    public init() {}

    public func getTemplate(_ template: SharingTemplate) -> SharingTemplateStyle {
        switch template {
        case .modern:
            return ModernTemplateStyle()
        case .minimal:
            return MinimalTemplateStyle()
        case .playful:
            return PlayfulTemplateStyle()
        case .professional:
            return ProfessionalTemplateStyle()
        case .budget:
            return BudgetTemplateStyle()
        case .awareness:
            return AwarenessTemplateStyle()
        }
    }
}

// MARK: - Sharing Templates

public enum SharingTemplate: String, CaseIterable {
    case modern
    case minimal
    case playful
    case professional
    case budget
    case awareness

    public var displayName: String {
        switch self {
        case .modern: return "Modern"
        case .minimal: return "Minimal"
        case .playful: return "Playful"
        case .professional: return "Professional"
        case .budget: return "Budget Focus"
        case .awareness: return "Time Awareness"
        }
    }

    public var description: String {
        switch self {
        case .modern: return "Clean design with gradients"
        case .minimal: return "Simple black and white"
        case .playful: return "Colorful with emojis"
        case .professional: return "Business-appropriate"
        case .budget: return "Budget tracking focused"
        case .awareness: return "Time awareness messaging"
        }
    }
}

// MARK: - Template Styles

public protocol SharingTemplateStyle {
    var backgroundColor: Color { get }
    var primaryColor: Color { get }
    var secondaryColor: Color { get }
    var textColor: Color { get }
    var accentColor: Color { get }
    var cornerRadius: CGFloat { get }
    var shadowRadius: CGFloat { get }
    var fontFamily: String { get }
}

public struct ModernTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color(red: 0.05, green: 0.05, blue: 0.1)
    public let primaryColor = Color.blue
    public let secondaryColor = Color.purple
    public let textColor = Color.white
    public let accentColor = Color.cyan
    public let cornerRadius: CGFloat = 20
    public let shadowRadius: CGFloat = 10
    public let fontFamily = "SF Pro Display"
}

public struct MinimalTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color.white
    public let primaryColor = Color.black
    public let secondaryColor = Color.gray
    public let textColor = Color.black
    public let accentColor = Color.blue
    public let cornerRadius: CGFloat = 8
    public let shadowRadius: CGFloat = 2
    public let fontFamily = "SF Pro Text"
}

public struct PlayfulTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color(red: 1.0, green: 0.95, blue: 0.8)
    public let primaryColor = Color.orange
    public let secondaryColor = Color.pink
    public let textColor = Color.black
    public let accentColor = Color.green
    public let cornerRadius: CGFloat = 25
    public let shadowRadius: CGFloat = 8
    public let fontFamily = "SF Pro Rounded"
}

public struct ProfessionalTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color(red: 0.95, green: 0.95, blue: 0.97)
    public let primaryColor = Color(red: 0.2, green: 0.3, blue: 0.5)
    public let secondaryColor = Color(red: 0.4, green: 0.5, blue: 0.6)
    public let textColor = Color.black
    public let accentColor = Color.blue
    public let cornerRadius: CGFloat = 12
    public let shadowRadius: CGFloat = 4
    public let fontFamily = "SF Pro Display"
}

public struct BudgetTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color(red: 0.1, green: 0.2, blue: 0.1)
    public let primaryColor = Color.green
    public let secondaryColor = Color.mint
    public let textColor = Color.white
    public let accentColor = Color.yellow
    public let cornerRadius: CGFloat = 16
    public let shadowRadius: CGFloat = 6
    public let fontFamily = "SF Pro Display"
}

public struct AwarenessTemplateStyle: SharingTemplateStyle {
    public let backgroundColor = Color(red: 0.2, green: 0.1, blue: 0.2)
    public let primaryColor = Color.purple
    public let secondaryColor = Color.indigo
    public let textColor = Color.white
    public let accentColor = Color.pink
    public let cornerRadius: CGFloat = 18
    public let shadowRadius: CGFloat = 8
    public let fontFamily = "SF Pro Display"
}

// MARK: - Calculation Sharing Card

@available(iOS 15.0, *)
public struct CalculationSharingCard: View {
    let price: Double
    let currency: String
    let workTime: String
    let template: SharingTemplate

    private var style: SharingTemplateStyle {
        SharingTemplateManager().getTemplate(template)
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(style.accentColor)

                Text("LifeMeter")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(style.textColor)
            }

            Spacer()

            // Main Content
            VStack(spacing: 16) {
                // Price
                VStack(spacing: 4) {
                    Text("Purchase Price")
                        .font(.subheadline)
                        .foregroundColor(style.secondaryColor)

                    Text("\(currency)\(String(format: "%.2f", price))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(style.primaryColor)
                }

                // Arrow or equals
                Image(systemName: "arrow.down")
                    .font(.title2)
                    .foregroundColor(style.accentColor)

                // Work Time
                VStack(spacing: 4) {
                    Text("Work Time Required")
                        .font(.subheadline)
                        .foregroundColor(style.secondaryColor)

                    Text(workTime)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(style.primaryColor)
                }
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Text("Understanding the true cost of purchases")
                    .font(.caption)
                    .foregroundColor(style.secondaryColor)
                    .multilineTextAlignment(.center)

                if template == .playful {
                    Text("💰 ⏰ 🤔")
                        .font(.title3)
                }
            }
        }
        .padding(32)
        .frame(width: 400, height: 600)
        .background(
            LinearGradient(
                colors: [style.backgroundColor, style.backgroundColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(style.cornerRadius)
        .shadow(radius: style.shadowRadius)
    }
}

// MARK: - Budget Sharing Card

@available(iOS 15.0, *)
public struct BudgetSharingCard: View {
    let summary: BudgetSummary
    let budgetName: String
    let template: SharingTemplate

    private var style: SharingTemplateStyle {
        SharingTemplateManager().getTemplate(template)
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 40))
                    .foregroundColor(style.accentColor)

                Text("Budget Tracker")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(style.textColor)
            }

            Spacer()

            // Budget Name
            Text(budgetName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(style.primaryColor)
                .multilineTextAlignment(.center)

            // Progress Circle
            ZStack {
                Circle()
                    .stroke(style.secondaryColor.opacity(0.3), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(summary.usedPercentage, 1.0))
                    .stroke(
                        summary.isOverBudget ? Color.red : style.primaryColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(summary.usedPercentage * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(style.textColor)

                    Text("used")
                        .font(.caption)
                        .foregroundColor(style.secondaryColor)
                }
            }

            // Stats
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Used")
                            .font(.caption)
                            .foregroundColor(style.secondaryColor)
                        Text(summary.formattedUsedTime)
                            .font(.headline)
                            .foregroundColor(style.textColor)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(style.secondaryColor)
                        Text(summary.formattedRemainingTime)
                            .font(.headline)
                            .foregroundColor(summary.isOverBudget ? Color.red : style.accentColor)
                    }
                }

                if summary.isOverBudget {
                    Text("⚠️ Over Budget")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Spacer()

            // Footer
            Text("Track your time budget with LifeMeter")
                .font(.caption)
                .foregroundColor(style.secondaryColor)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 400, height: 600)
        .background(
            LinearGradient(
                colors: [style.backgroundColor, style.backgroundColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(style.cornerRadius)
        .shadow(radius: style.shadowRadius)
    }
}

// MARK: - Awareness Sharing Card

@available(iOS 15.0, *)
public struct AwarenessSharingCard: View {
    let totalCalculations: Int
    let totalWorkTime: String
    let template: SharingTemplate

    private var style: SharingTemplateStyle {
        SharingTemplateManager().getTemplate(template)
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 40))
                    .foregroundColor(style.accentColor)

                Text("Time Awareness")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(style.textColor)
            }

            Spacer()

            // Main Message
            VStack(spacing: 16) {
                Text("I've calculated")
                    .font(.headline)
                    .foregroundColor(style.secondaryColor)

                Text("\(totalCalculations)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(style.primaryColor)

                Text("purchases")
                    .font(.headline)
                    .foregroundColor(style.secondaryColor)

                Text("representing")
                    .font(.subheadline)
                    .foregroundColor(style.secondaryColor)

                Text(totalWorkTime)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(style.accentColor)

                Text("of work time")
                    .font(.headline)
                    .foregroundColor(style.secondaryColor)
            }
            .multilineTextAlignment(.center)

            Spacer()

            // Call to Action
            VStack(spacing: 8) {
                Text("Understanding the true cost of purchases")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(style.textColor)
                    .multilineTextAlignment(.center)

                Text("Get LifeMeter and start your journey")
                    .font(.caption)
                    .foregroundColor(style.secondaryColor)
                    .multilineTextAlignment(.center)

                if template == .playful {
                    Text("🎯 💡 ⏰")
                        .font(.title3)
                }
            }
        }
        .padding(32)
        .frame(width: 400, height: 600)
        .background(
            LinearGradient(
                colors: [style.backgroundColor, style.backgroundColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(style.cornerRadius)
        .shadow(radius: style.shadowRadius)
    }
}

// MARK: - Sharing Error

public enum SharingError: LocalizedError {
    case imageGenerationFailed
    case templateNotFound
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .imageGenerationFailed:
            return "Failed to generate sharing image"
        case .templateNotFound:
            return "Sharing template not found"
        case .invalidData:
            return "Invalid data provided for sharing"
        }
    }
}
