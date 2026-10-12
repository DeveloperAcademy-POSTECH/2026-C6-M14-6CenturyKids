import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

/// 화면 입력 안내용 검증. Domain 생성자와 서버 검증을 대체하지 않습니다.
enum AuthFormValidation {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func emailError(_ value: String) -> String? {
        let email = trimmed(value)
        guard !email.isEmpty else { return "이메일을 입력해 주세요." }
        let pattern = #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#
        guard email.range(of: pattern, options: .regularExpression) != nil,
              !email.hasPrefix("."), !email.contains(".."), !email.contains(".@") else {
            return "이메일 형식을 확인해 주세요."
        }
        return nil
    }

    static func nameError(_ value: String) -> String? {
        let name = trimmed(value)
        guard !name.isEmpty else { return "이름을 입력해 주세요." }
        guard name.count <= 10 else { return "이름은 10자 이내로 입력해 주세요." }
        guard name.rangeOfCharacter(from: .controlCharacters) == nil else {
            return "이름에 줄바꿈을 사용할 수 없어요."
        }
        return nil
    }

    static func passwordError(_ value: String) -> String? {
        guard value.count >= 8,
              value.range(of: "[A-Za-z]", options: .regularExpression) != nil,
              value.range(of: "[0-9]", options: .regularExpression) != nil else {
            return "영문·숫자를 포함해 8자 이상 입력해 주세요."
        }
        return nil
    }
}

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
