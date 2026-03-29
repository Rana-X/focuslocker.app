// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusLocker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FocusLockerKit",
            targets: ["FocusLockerKit"]
        ),
        .executable(
            name: "FocusLocker",
            targets: ["FocusLocker"]
        ),
        .executable(
            name: "FocusLockerAgent",
            targets: ["FocusLockerAgent"]
        )
    ],
    targets: [
        .target(
            name: "FocusLockerKit"
        ),
        .executableTarget(
            name: "FocusLocker",
            dependencies: ["FocusLockerKit"]
        ),
        .executableTarget(
            name: "FocusLockerAgent",
            dependencies: ["FocusLockerKit"]
        )
    ]
)
