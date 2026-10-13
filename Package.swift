// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToDocTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocCoreErrors", path: "ToDoc/Core/Errors"),
        .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"], path: "ToDoc/Domain"),
        .target(name: "AuthScreens", dependencies: ["ToDocDomain"], path: "ToDoc/Features/Auth/Presentation"),
        .testTarget(name: "AuthScreenTests", dependencies: ["AuthScreens"], path: "Tests/AuthScreenTests"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain", "ToDocCoreErrors"], path: "Tests/DomainTests")
    ],
    swiftLanguageModes: [.v5]
)
