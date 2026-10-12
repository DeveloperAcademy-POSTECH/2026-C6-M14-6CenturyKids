// swift-tools-version: 6.0
import PackageDescription

// 앱의 Foundation 기반 Domain 소스를 별도 패키지에서도 검증합니다.
let package = Package(
    name: "ToDocDomainTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocCoreErrors", path: "ToDoc/Core/Errors"),
        .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"], path: "ToDoc/Domain"),
        // 케어콜 준비 상태 단위 테스트 전용입니다. 앱·서비스·DI 설정은 변경하지 않습니다.
        .target(name: "CareCallPresentation", path: "ToDoc/Features/Symptom/ViewModels"),
        .testTarget(name: "CareCallPresentationTests", dependencies: ["CareCallPresentation"],
                    path: "Tests/CareCallPresentationTests"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain", "ToDocCoreErrors"], path: "Tests/DomainTests")
    ],
    swiftLanguageModes: [.v5]
)
