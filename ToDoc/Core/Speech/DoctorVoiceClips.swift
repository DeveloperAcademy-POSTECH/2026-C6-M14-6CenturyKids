//
//  DoctorVoiceClips.swift
//  ToDoc
//
//  Created by seokho on 11/9/26.
//

import Foundation

/// 의사 선생님이 녹음한 말 조각과 그 파일 이름 (Resources/Config/doctor_voice.json: 조각 문장 → DoctorVoice/<이름>.m4a).
/// 케어콜이 하는 말은 설정 문구를 이어 붙인 것이라, 문장 끝(. ? !)과 맨 앞 한 낱말 맞장구("알겠어요,") 뒤에서 나눠 조각마다 녹음했다
struct DoctorVoiceClips: Decodable {
    private let names: [String: String]

    init(names: [String: String]) {
        self.names = names
    }

    init(from decoder: Decoder) throws {
        names = try decoder.singleValueContainer().decode([String: String].self)
    }

    /// 말할 문장의 조각 파일 이름들. 녹음이 없는 조각이 하나라도 있으면 nil
    /// (한 문장 안에서 목소리가 바뀌지 않게 그 문장은 기기 음성으로 읽는다)
    func clipNames(for text: String) -> [String]? {
        guard let pieces = Self.pieces(of: text), !pieces.isEmpty else { return nil }
        let found = pieces.compactMap { names[$0] }
        return found.count == pieces.count ? found : nil
    }

    /// "알겠어요, 기억해 둘게요. 이제 다른 증상들에 대해서 물어볼게요." → ["알겠어요.", "기억해 둘게요.", "이제 다른 증상들에 대해서 물어볼게요."].
    /// 문장 부호로 끝나지 않는 말은 나누지 않는다 (nil)
    static func pieces(of text: String) -> [String]? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = text.last, ".?!".contains(last) else { return nil }
        return text.matches(of: /[^.?!]+[.?!]/).flatMap { match -> [String] in
            let piece = String(match.output).trimmingCharacters(in: .whitespaces)
            if let lead = piece.wholeMatch(of: /([가-힣]+요), (.+)/) {
                return [String(lead.1) + ".", String(lead.2)]
            }
            return [piece]
        }
    }
}
