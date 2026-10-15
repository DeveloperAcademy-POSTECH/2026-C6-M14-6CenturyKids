import Foundation

nonisolated struct OpenSourceLicense: Identifiable, Sendable {
    let name: String
    let licenseName: String
    let resourceName: String
    let resourceDirectory: String
    var id: String { resourceName }

    // Xcode가 리소스를 평탄화한 번들과 폴더를 유지한 번들을 모두 지원합니다.
    func loadText(in bundle: Bundle = .main) -> String? {
        for directory in [nil, resourceDirectory] as [String?] {
            guard let url = bundle.url(forResource: resourceName, withExtension: "txt",
                                       subdirectory: directory) else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return text
        }
        return nil
    }

    static let bundled: [Self] = [
        .init(name: "Pretendard", licenseName: "SIL Open Font License 1.1",
              resourceName: "Pretendard-LICENSE", resourceDirectory: "Fonts"),
        .init(name: "ONNX Runtime", licenseName: "MIT License",
              resourceName: "ONNXRuntime-MIT", resourceDirectory: "Licenses"),
        .init(name: "Supertonic · 코드", licenseName: "MIT License",
              resourceName: "Supertonic-Code-MIT", resourceDirectory: "Licenses"),
        .init(name: "Supertonic · 음성 모델", licenseName: "OpenRAIL-M License",
              resourceName: "Supertonic-Model-OpenRAIL-M", resourceDirectory: "Licenses"),
        .init(name: "CoreAI Models", licenseName: "BSD 3-Clause License",
              resourceName: "CoreAIModels-BSD-3-Clause", resourceDirectory: "Licenses"),
        .init(name: "Kanana", licenseName: "Apache License 2.0",
              resourceName: "Kanana-Apache-2.0", resourceDirectory: "Licenses"),
        .init(name: "Kanana · 고지", licenseName: "NOTICE",
              resourceName: "Kanana-NOTICE", resourceDirectory: "Licenses"),
        .init(name: "CoreAILM · 의존성", licenseName: "Third-party notices",
              resourceName: "ThirdPartyNotices-CoreAILM", resourceDirectory: "Licenses")
    ]
}
