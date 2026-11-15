//
//  MicGate.swift
//  ToDoc
//
//  Created by seokho on 11/15/26.
//

import Foundation

/// 수음 강도 조절: 가까이서 말하는 큰 소리만 통과시킨다 (시끄러운 곳에서 주변 사람 목소리를 거르려고).
/// 기준보다 큰 소리가 나면 열리고, 그 뒤 잠깐은 작은 소리도 통과시켜 말끝이 잘리지 않게 한다
nonisolated struct MicGate {
    /// 관리자 설정 슬라이더가 저장하는 키. 값이 없으면 기본값
    static let thresholdKey = "demo.micGateThreshold"
    /// 20cm에서 말하는 목소리 기준. 실기기에서 잰 한 턴의 최대 소리(RMS)가 0.14~0.37이었고(2026-11-13, 거리는 재지 않음),
    /// 소리는 거리가 두 배면 반으로 줄어 같은 목소리가 80cm쯤 떨어지면 이 값 아래가 된다. 현장 소음에 맞춰 슬라이더로 고친다
    static let defaultThreshold = 0.08
    static var savedThreshold: Float {
        Float(UserDefaults.standard.object(forKey: thresholdKey) as? Double ?? defaultThreshold)
    }
    /// 큰 소리 뒤 이만큼은 열어 둔다 (낱말 사이 틈과 작은 말끝)
    static let hold: Duration = .milliseconds(500)

    /// 이 크기(RMS) 이상이면 가까이서 말하는 소리로 본다. 0이면 거르지 않는다
    let threshold: Float
    private var openUntil: ContinuousClock.Instant?

    init(threshold: Float) {
        self.threshold = threshold
    }

    /// 이 크기의 소리를 통과시킬지
    mutating func passes(level: Float, at now: ContinuousClock.Instant) -> Bool {
        guard threshold > 0 else { return true }
        if level >= threshold {
            openUntil = now + Self.hold
            return true
        }
        return openUntil.map { now < $0 } ?? false
    }
}
