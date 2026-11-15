import Testing
@testable import ToDocCareCall

struct MicGateTests {
    private let start = ContinuousClock.now

    /// 차례로 들어온 소리(크기, 시작 뒤 ms)마다 통과했는지
    private func passes(threshold: Float, _ sounds: [(level: Float, ms: Int)]) -> [Bool] {
        var gate = MicGate(threshold: threshold)
        return sounds.map { gate.passes(level: $0.level, at: start + .milliseconds($0.ms)) }
    }

    @Test func 기준보다_작은_소리는_거르고_큰_소리는_통과시킨다() {
        #expect(passes(threshold: 0.08, [(0.03, 0), (0.2, 100)]) == [false, true])
    }

    @Test func 큰_소리_뒤_잠깐은_작은_소리도_통과시키고_그_뒤에는_거른다() {
        // 말끝(0.4초 뒤)은 통과, 말이 끝난 뒤의 주변 목소리는 거른다
        #expect(passes(threshold: 0.08, [(0.2, 0), (0.01, 400), (0.01, 600), (0.07, 2000)]) == [true, true, false, false])
    }

    @Test func 기준이_0이면_모두_통과시킨다() {
        #expect(passes(threshold: 0, [(0, 0)]) == [true])
    }
}
