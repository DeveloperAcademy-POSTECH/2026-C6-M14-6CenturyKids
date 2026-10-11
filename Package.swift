// swift-tools-version: 6.0
import PackageDescription

// 앱의 Foundation 기반 Domain 소스를 별도 패키지에서도 검증합니다.
let package = Package(
    name: "ToDocDomainTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocCoreErrors", path: "ToDoc/Core/Errors"),
        .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"], path: "ToDoc/Domain"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain", "ToDocCoreErrors"], path: "Tests/DomainTests")
    ],
    swiftLanguageModes: [.v5]
)
