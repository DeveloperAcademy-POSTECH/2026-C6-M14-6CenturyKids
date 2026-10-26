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
        // Swift 패키지(Supabase 등) 고지는 tools/generate_license_notices.py로 만든다
        .init(name: "Supabase 등 오픈소스 패키지", licenseName: "MIT · Apache License 2.0",
              resourceName: "ThirdPartyNotices-Packages", resourceDirectory: "Licenses")
    ]
}
