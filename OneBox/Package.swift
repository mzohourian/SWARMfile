// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneBox",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "CommonTypes", targets: ["CommonTypes"]),
        .library(name: "CorePDF", targets: ["CorePDF"]),
        .library(name: "CoreImageKit", targets: ["CoreImageKit"]),
        .library(name: "JobEngine", targets: ["JobEngine"]),
        .library(name: "Payments", targets: ["Payments"]),
        .library(name: "Ads", targets: ["Ads"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
        .library(name: "Privacy", targets: ["Privacy"]),
    ],
    dependencies: [],
    targets: [
        // Common Types
        .target(
            name: "CommonTypes",
            dependencies: [],
            path: "Modules/CommonTypes"
        ),
        
        // Core Processing Modules
        .target(
            name: "CorePDF",
            dependencies: ["CommonTypes"],
            path: "Modules/CorePDF"
        ),
        .target(
            name: "CoreImageKit",
            dependencies: ["CommonTypes"],
            path: "Modules/CoreImageKit"
        ),

        // Privacy Module
        .target(
            name: "Privacy",
            dependencies: [],
            path: "Modules/Privacy"
        ),

        // Job Engine
        .target(
            name: "JobEngine",
            dependencies: ["CommonTypes", "CorePDF", "CoreImageKit", "Privacy"],
            path: "Modules/JobEngine"
        ),

        // Payments & Ads
        .target(
            name: "Payments",
            dependencies: [],
            path: "Modules/Payments"
        ),
        .target(
            name: "Ads",
            dependencies: [],
            path: "Modules/Ads"
        ),

        // UI Components
        .target(
            name: "UIComponents",
            dependencies: [],
            path: "Modules/UIComponents"
        ),

        // Tests
        .testTarget(
            name: "CorePDFTests",
            dependencies: ["CorePDF"],
            path: "Tests/CorePDFTests"
        ),
        .testTarget(
            name: "CoreImageKitTests",
            dependencies: ["CoreImageKit"],
            path: "Tests/CoreImageKitTests"
        ),
        .testTarget(
            name: "JobEngineTests",
            dependencies: ["JobEngine"],
            path: "Tests/JobEngineTests"
        ),
        .testTarget(
            name: "PaymentsTests",
            dependencies: ["Payments"],
            path: "Tests/PaymentsTests"
        ),
        .testTarget(
            name: "PrivacyTests",
            dependencies: ["Privacy"],
            path: "Tests/PrivacyTests"
        ),
    ]
)
