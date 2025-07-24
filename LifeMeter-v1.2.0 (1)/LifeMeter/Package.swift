// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LifeMeter",
    platforms: [
        .iOS(.v15),
        .watchOS(.v8),
        .macOS(.v12)
    ],
    products: [
        .library(name: "WageOnboarding", targets: ["WageOnboarding"]),
        .library(name: "PriceCapture", targets: ["PriceCapture"]),
        .library(name: "CalcCore", targets: ["CalcCore"]),
        .library(name: "CatRenderer", targets: ["CatRenderer"]),
        .library(name: "HistoryStore", targets: ["HistoryStore"]),
        .library(name: "LifeWidget", targets: ["LifeWidget"]),
        .library(name: "AppShell", targets: ["AppShell"])
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
                "HistoryStore"
            ],
            path: "Modules/AppShell/Sources"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Modules/AppShell/Tests"
        )
    ]
)

