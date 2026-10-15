import Foundation
import Observation

/// 시스템 권한의 화면 투영입니다. 앱 수신 설정이나 DB enum과 별개입니다.
nonisolated enum NotificationAuthorization: Equatable, Sendable {
    case unknown, notDetermined, denied, authorized, provisional, ephemeral
    var displayName: String {
        switch self {
        case .unknown: "확인할 수 없음"
        case .notDetermined: "아직 요청하지 않음"
        case .denied: "허용하지 않음"
        case .authorized: "허용됨"
        case .provisional: "조용한 알림 허용됨"
        case .ephemeral: "일시적으로 허용됨"
        }
    }
}
