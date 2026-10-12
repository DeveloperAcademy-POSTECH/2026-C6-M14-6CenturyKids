import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

/// 서비스 어댑터가 화면에 안전하게 표시할 수 있는 실패만 전달합니다.
/// 원본 서버 오류에는 개인정보가 있을 수 있으므로 그대로 노출하지 않습니다.
enum AuthPresentationError: Error {
    case unavailable
    case message(String)

    static func message(for error: Error, fallback: String) -> String {
        switch error {
        case Self.unavailable: "아직 서비스를 연결하고 있어요. 잠시 후 다시 시도해 주세요."
        case Self.message(let message): message
        case is ProfileLookupError: "계정 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
        default: fallback
        }
    }
}
