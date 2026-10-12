// swift-tools-version: 6.0
import PackageDescription

// Domain과 인증 프레젠테이션의 실제 소스를 별도 패키지에서도 검증합니다.
let package = Package(
    name: "ToDocDomainTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocCoreErrors", path: "ToDoc/Core/Errors"),
        .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"], path: "ToDoc/Domain"),
        .target(name: "AuthPresentation", dependencies: ["ToDocDomain", "ToDocCoreErrors"],
                path: "ToDoc/Features/Auth/ViewModels"),
        .testTarget(name: "AuthPresentationTests", dependencies: ["AuthPresentation", "ToDocDomain", "ToDocCoreErrors"],
                    path: "Tests/AuthPresentationTests"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain", "ToDocCoreErrors"], path: "Tests/DomainTests")
    ],
    swiftLanguageModes: [.v5]
)
