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
    static func passwordChangeError(_ value: String) -> String? {
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let digits = CharacterSet(charactersIn: "0123456789")
        let specialCharacters = CharacterSet.punctuationCharacters.union(.symbols)

        let characters = value.unicodeScalars
        let hasLetter = characters.contains { letters.contains($0) }
        let hasDigit = characters.contains { digits.contains($0) }
        let hasSpecialCharacter = characters.contains { specialCharacters.contains($0) }
        let containsOnlyAllowedCharacters = characters.allSatisfy {
            $0.isASCII &&
            (letters.contains($0) || digits.contains($0) || specialCharacters.contains($0))
        }

        guard (8...32).contains(value.count),
              hasLetter,
              hasDigit,
              hasSpecialCharacter,
              containsOnlyAllowedCharacters else {
            return "영문, 숫자, 특수문자를 조합해 8~32자로 입력해 주세요."
        }
        return nil
    }
    static func nameError(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.count > 10 || trimmed.rangeOfCharacter(from: .controlCharacters) != nil
            ? "이름은 1~10자로 입력해 주세요." : nil
    }
}
