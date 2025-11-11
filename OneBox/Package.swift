// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OneBox",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "CorePDF", targets: ["CorePDF"]),
        .library(name: "CoreImageKit", targets: ["CoreImageKit"]),
        .library(name: "VideoProcessor", targets: ["VideoProcessor"]),
        .library(name: "CoreZip", targets: ["CoreZip"]),
        .library(name: "JobEngine", targets: ["JobEngine"]),
        .library(name: "Payments", targets: ["Payments"]),
        .library(name: "Ads", targets: ["Ads"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
    ],
    dependencies: [],
    targets: [
        // Core Processing Modules
        .target(
            name: "CorePDF",
            dependencies: [],
            path: "Modules/CorePDF"
        ),
        .target(
            name: "CoreImageKit",
            dependencies: [],
            path: "Modules/CoreImageKit"
        ),
        .target(
            name: "VideoProcessor",
            dependencies: [],
            path: "Modules/VideoProcessor"
        ),
        .target(
            name: "CoreZip",
            dependencies: [],
            path: "Modules/CoreZip"
        ),

        // Job Engine
        .target(
            name: "JobEngine",
            dependencies: ["CorePDF", "CoreImageKit", "VideoProcessor", "CoreZip"],
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
            name: "VideoProcessorTests",
            dependencies: ["VideoProcessor"],
            path: "Tests/VideoProcessorTests"
        ),
        .testTarget(
            name: "CoreZipTests",
            dependencies: ["CoreZip"],
            path: "Tests/CoreZipTests"
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
    ]
)
