import Foundation
import Security
import CryptoKit

enum NonceCreator {
    static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                throw AuthFlowError("인증 요청을 준비하지 못했어요. 다시 시도해 주세요.")
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}
