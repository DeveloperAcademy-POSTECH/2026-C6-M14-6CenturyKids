import Foundation

nonisolated enum HomeGreeting {
    /// 홈 안내 문구입니다. 실제 의료진 코멘트나 기록 저장 결과가 아닙니다.
    static func text(for patientName: String?) -> String {
        let message = "오늘도 기록을 해주셨네"
        guard let name = patientName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return message
        }
        let last = name.precomposedStringWithCanonicalMapping.unicodeScalars.last?.value ?? 0
        let hasFinalConsonant = (0xAC00...0xD7A3).contains(last) && (last - 0xAC00) % 28 != 0
        return "\(name)\(hasFinalConsonant ? "이" : "가") \(message)"
    }
}
