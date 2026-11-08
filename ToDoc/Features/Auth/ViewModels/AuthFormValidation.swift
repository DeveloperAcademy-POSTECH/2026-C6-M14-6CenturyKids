import Foundation

/// 화면 입력 검증만 담당하는 값 함수들입니다. 네트워크 요청이나 저장은 하지 않습니다.
enum AuthFormValidation {
    static func email(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func emailError(_ text: String) -> String? {
        let value = email(text)
        return value.range(of: #"^[A-Z0-9a-z.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.[A-Za-z]{2,}$"#, options: .regularExpression) == nil
            ? "이메일 주소를 확인해 주세요." : nil
    }
    static func passwordError(_ value: String) -> String? {
        guard (8...20).contains(value.count),
              value.range(of: "[A-Za-z]", options: .regularExpression) != nil,
              value.range(of: "[0-9]", options: .regularExpression) != nil else {
            return "비밀번호는 영문과 숫자를 포함해 8~20자로 입력해 주세요."
        }
        return nil
    }
    static func passwordChangeError(_ value: String) -> String? {
        passwordError(value)
    }
    static func nameError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 30 { return "이름은 1~30자로 입력해 주세요." }
        let disallowed = CharacterSet.controlCharacters.union(.punctuationCharacters).union(.symbols)
        return trimmed.rangeOfCharacter(from: disallowed) != nil ? "이름을 다시 확인해 주세요." : nil
    }
}
