import Foundation

nonisolated enum SignupTerm: CaseIterable, Hashable, Identifiable, Sendable {
    case service, privacy, sensitiveInformation, doctorConnection, thirdPartyProvision, appUsage
    var id: Self { self }
    var isRequired: Bool { true }
    var title: String {
        switch self {
        case .service: "서비스 이용약관 동의"
        case .privacy: "개인정보 수집·이용 동의"
        case .sensitiveInformation: "환자 건강정보 수집·이용 동의"
        case .doctorConnection: "의료진·병원 정보 연동 동의"
        case .thirdPartyProvision: "제3자 제공 동의"
        case .appUsage: "앱 이용정보 수집·이용 동의"
        }
    }
    var fullTitle: String {
        let agreement: String
        switch self {
        case .service: agreement = "서비스 이용약관에 동의합니다."
        case .privacy: agreement = "개인정보 수집·이용에 동의합니다."
        case .sensitiveInformation: agreement = "환자 건강정보 수집·이용에 동의합니다."
        case .doctorConnection: agreement = "의료진·병원 정보 연동에 동의합니다."
        case .thirdPartyProvision: agreement = "제3자 제공에 동의합니다."
        case .appUsage: agreement = "앱 이용정보 수집·이용에 동의합니다."
        }
        return "[필수] \(agreement)"
    }
}
