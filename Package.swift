// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Reprise",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "RepriseApp", targets: ["RepriseApp"]),
        .executable(name: "reprise", targets: ["reprise"]),
        .library(name: "RepriseCore", targets: ["RepriseCore"]),
    ],
    targets: [
        .target(
            name: "RepriseCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "RepriseApp",
            dependencies: ["RepriseCore"],
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        .executableTarget(
            name: "reprise",
            dependencies: ["RepriseCore"]
        ),
        .executableTarget(
            name: "reprise-bench",
            dependencies: ["RepriseCore"]
        ),
        .testTarget(
            name: "RepriseCoreTests",
            dependencies: ["RepriseCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
