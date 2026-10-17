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
        guard value.count >= 8, value.rangeOfCharacter(from: .letters) != nil,
              value.rangeOfCharacter(from: .decimalDigits) != nil else { return "비밀번호는 영문과 숫자를 포함해 8자 이상 입력해 주세요." }
        return nil
    }
    static func nameError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.count > 10 || trimmed.rangeOfCharacter(from: .controlCharacters) != nil
            ? "이름은 1~10자로 입력해 주세요." : nil
    }
}
