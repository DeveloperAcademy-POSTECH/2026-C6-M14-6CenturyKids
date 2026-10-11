//
//  SupertonicVoice.swift
//  ToDoc
//
//  Created by seokho on 10/11/26.
//

import Foundation
import OnnxRuntimeBindings

/// Supertonic 3 합성기: 목소리 M3, fp32 ONNX, ONNX Runtime CPU. actor라 합성은 메인 스레드 밖에서 돈다.
/// 아이폰 17 측정(프로토타입, 단독): 로드 0.5초, 메모리 약 0.9GB, 문장당 합성 0.5~1.7초 (음성 길이의 약 1/3).
/// 문장 단위로 합성해 캐시한다. 앱이 하는 말은 대부분 설정 파일의 고정 문구라 두 번째부터는 바로 나온다.
actor SupertonicVoice {
    static let folderName = "supertonic-3"
    static let voiceStyle = "M3"
    /// 원본 긴 글 합성이 덩어리 사이에 넣는 쉼과 같은 값 (초)
    static let pauseBetweenSentences = 0.3
    /// 원본 예제의 합성 단계 수 (클수록 품질이 좋고 느리다)
    static let totalSteps = 8

    let sampleRate: Int
    private let env: ORTEnv
    private let tts: Supertonic.TextToSpeech
    private let style: Supertonic.Style
    // ponytail: 캐시 크기 제한 없음 (고정 문구 위주라 수십 문장). 동적 문장이 많아지면 오래된 것부터 지우는 방식으로 제한
    private var cache: [String: [Float]] = [:]

    /// 앱에 모델 폴더가 없으면 nil (빌드 단계에서 Models/supertonic-3이 있을 때만 복사한다)
    init?() throws {
        guard let folder = Bundle.main.url(forResource: Self.folderName, withExtension: nil) else { return nil }
        env = try ORTEnv(loggingLevel: .warning)
        tts = try Supertonic.loadTextToSpeech(folder.path, false, env)
        style = try Supertonic.loadVoiceStyle([folder.appending(path: "\(Self.voiceStyle).json").path], verbose: false)
        sampleRate = tts.sampleRate
    }

    /// 여러 문장으로 된 말: 문장마다 (캐시에서) 합성해 짧은 쉼을 두고 잇는다
    func utterance(_ text: String) throws -> [Float] {
        let pause = [Float](repeating: 0, count: Int(Double(sampleRate) * Self.pauseBetweenSentences))
        var out: [Float] = []
        for (i, s) in Self.sentences(text).enumerated() {
            if i > 0 { out += pause }
            out += try sentence(s)
        }
        return out
    }

    /// 한 문장의 음성 (캐시)
    private func sentence(_ text: String) throws -> [Float] {
        if let hit = cache[text] { return hit }
        let (wav, duration) = try tts.call(text, "ko", style, Self.totalSteps)
        let samples = Array(wav.prefix(Int(Double(sampleRate) * Double(duration))))
        cache[text] = samples
        return samples
    }

    /// 문장 끝(. ? !) 뒤 공백에서 나눈다. "0.5" 같은 소수점은 뒤에 공백이 없어 나뉘지 않는다
    nonisolated static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var previous: Character?
        for c in text {
            if c.isWhitespace, let p = previous, ".?!".contains(p) {
                result.append(current)
                current = ""
            } else if !(c.isWhitespace && current.isEmpty) {
                current.append(c)
            }
            previous = c
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// 16비트 PCM WAV (AVAudioPlayer로 재생)
    nonisolated static func wavData(_ samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        for s in samples { append(Int16(max(-1, min(1, s)) * Float(Int16.max))) }
        return data
    }
}
