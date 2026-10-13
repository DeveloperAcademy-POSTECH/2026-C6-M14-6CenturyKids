import Foundation

nonisolated enum SignupTerm: CaseIterable, Hashable, Identifiable, Sendable {
    case service, privacy, sensitiveInformation, notifications
    var id: Self { self }
    var isRequired: Bool { self != .notifications }
    var title: String {
        switch self {
        case .service: "서비스 이용약관"
        case .privacy: "개인정보 수집 및 이용 동의"
        case .sensitiveInformation: "민감정보 수집 및 이용 동의"
        case .notifications: "서비스 알림 수신 동의"
        }
    }
    var fullTitle: String { "[\(isRequired ? "필수" : "선택")] \(title)" }
}
