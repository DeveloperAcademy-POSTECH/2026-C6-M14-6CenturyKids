import Foundation

enum LocalStoreError: LocalizedError {
    case missingRecord, unavailableAccountAction, followUpNotReady
    var errorDescription: String? {
        switch self {
        case .missingRecord: "기기에 저장된 기록을 찾지 못했어요."
        case .unavailableAccountAction: "이 앱은 로그인과 서버 연결 없이 기기에만 저장해요."
        case .followUpNotReady: "가장 최근 통증 기록의 복용 후 기록 시간이 아직 되지 않았어요."
        }
    }
}
