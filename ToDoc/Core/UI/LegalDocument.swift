import Foundation

nonisolated enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: Self { self }

    var title: String {
        switch self {
        case .terms: "이용약관"
        case .privacy: "개인정보 처리방침"
        }
    }

    var address: String {
        switch self {
        case .terms: "https://nuarc.notion.site/socdoc-terms-of-use"
        case .privacy: "https://nuarc.notion.site/socdoc-privacy-policy"
        }
    }
}
