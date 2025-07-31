// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LifeMeter",
    platforms: [
        .iOS(.v15),
        .watchOS(.v8),
        .macOS(.v12),
    ],
    products: [
        .library(name: "WageOnboarding", targets: ["WageOnboarding"]),
        .library(name: "PriceCapture", targets: ["PriceCapture"]),
        .library(name: "CalcCore", targets: ["CalcCore"]),
        .library(name: "LifeCore", targets: ["LifeCore"]),
        .library(name: "CatRenderer", targets: ["CatRenderer"]),
        .library(name: "HistoryStore", targets: ["HistoryStore"]),
        .library(name: "LifeWidget", targets: ["LifeWidget"]),
        .library(name: "AppShell", targets: ["AppShell"]),
        // Newly exposed modules
        .library(name: "ExchangeRates", targets: ["ExchangeRates"]),
        .library(name: "TimeBudget", targets: ["TimeBudget"]),
        .library(name: "SocialSharing", targets: ["SocialSharing"]),
        .library(name: "TransactionLogger", targets: ["TransactionLogger"]),
    ],
    dependencies: [
        // No external dependencies - privacy-first approach
    ],
    targets: [
        // MARK: - Core Modules

        .target(
            name: "CalcCore",
            path: "Modules/CalcCore/Sources"
        ),
        .testTarget(
            name: "CalcCoreTests",
            dependencies: ["CalcCore"],
            path: "Modules/CalcCore/Tests"
        ),

        .target(
            name: "LifeCore",
            path: "Modules/LifeCore/Sources"
        ),
        .testTarget(
            name: "LifeCoreTests",
            dependencies: ["LifeCore"],
            path: "Modules/LifeCore/Tests"
        ),

        // MARK: - Data Layer

        .target(
            name: "HistoryStore",
            dependencies: ["CalcCore"],
            path: "Modules/HistoryStore/Sources"
        ),
        .testTarget(
            name: "HistoryStoreTests",
            dependencies: ["HistoryStore"],
            path: "Modules/HistoryStore/Tests"
        ),

        // MARK: - UI Modules

        .target(
            name: "WageOnboarding",
            dependencies: ["CalcCore", "HistoryStore"],
            path: "Modules/WageOnboarding/Sources"
        ),
        .testTarget(
            name: "WageOnboardingTests",
            dependencies: ["WageOnboarding"],
            path: "Modules/WageOnboarding/Tests"
        ),

        .target(
            name: "PriceCapture",
            dependencies: ["CalcCore"],
            path: "Modules/PriceCapture/Sources"
        ),
        .testTarget(
            name: "PriceCaptureTests",
            dependencies: ["PriceCapture"],
            path: "Modules/PriceCapture/Tests"
        ),

        .target(
            name: "CatRenderer",
            dependencies: ["CalcCore"],
            path: "Modules/CatRenderer/Sources"
        ),
        .testTarget(
            name: "CatRendererTests",
            dependencies: ["CatRenderer"],
            path: "Modules/CatRenderer/Tests"
        ),

        // MARK: - Utility Modules

        .target(
            name: "ExchangeRates",
            dependencies: ["CalcCore"],
            path: "Modules/ExchangeRates/Sources"
        ),
        .testTarget(
            name: "ExchangeRatesTests",
            dependencies: ["ExchangeRates"],
            path: "Tests/ExchangeRatesTests"
        ),
        .testTarget(
            name: "CurrencyStoreTests",
            dependencies: ["CalcCore"],
            path: "Tests/CurrencyStoreTests"
        ),

        .target(
            name: "TimeBudget",
            dependencies: ["AppShell", "HistoryStore"],
            path: "Modules/TimeBudget/Sources"
        ),
        .testTarget(
            name: "TimeBudgetTests",
            dependencies: ["TimeBudget"],
            path: "Modules/TimeBudget/Tests"
        ),

        .target(
            name: "SocialSharing",
            path: "Modules/SocialSharing/Sources"
        ),
        .testTarget(
            name: "SocialSharingTests",
            dependencies: ["SocialSharing"],
            path: "Modules/SocialSharing/Tests"
        ),

        .target(
            name: "TransactionLogger",
            dependencies: ["CalcCore", "HistoryStore"],
            path: "Modules/TransactionLogger/Sources"
        ),
        .testTarget(
            name: "TransactionLoggerTests",
            dependencies: ["TransactionLogger", "CalcCore", "HistoryStore"],
            path: "Modules/TransactionLogger/Tests"
        ),

        // MARK: - Widget Extension

        .target(
            name: "LifeWidget",
            dependencies: ["CalcCore", "CatRenderer", "HistoryStore"],
            path: "Modules/LifeWidget/Sources"
        ),
        .testTarget(
            name: "LifeWidgetTests",
            dependencies: ["LifeWidget"],
            path: "Modules/LifeWidget/Tests"
        ),

        // MARK: - App Shell

        .target(
            name: "AppShell",
            dependencies: [
                "WageOnboarding",
                "PriceCapture",
                "CalcCore",
                "CatRenderer",
                "HistoryStore",
            ],
            path: "Modules/AppShell/Sources"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Modules/AppShell/Tests"
        ),
    ]
)

