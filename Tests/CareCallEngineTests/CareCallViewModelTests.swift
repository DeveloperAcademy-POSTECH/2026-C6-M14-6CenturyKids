import Foundation
import Testing
@testable import ToDocCareCall

/// 케어콜 준비 단계를 흉내 내는 가짜 서비스. 단계마다 오류를 낼 수 있고, hold 단계에서 release()까지 붙잡는다
@MainActor
final class FakePreparer: CareCallPreparing {
    enum Step { case microphone, model, speech }
    private(set) var calls: [Step] = []
    var errors: [Step: Error] = [:]
    var hold: Step?
    var isHolding: Bool { held != nil }
    private var held: CheckedContinuation<Void, Never>?

    func requestMicrophone() async throws { try await run(.microphone) }
    func loadModel() async throws { try await run(.model) }
    func prepareSpeech() async throws { try await run(.speech) }

    func release() {
        held?.resume()
        held = nil
    }

    private func run(_ step: Step) async throws {
        calls.append(step)
        if hold == step {
            hold = nil
            await withCheckedContinuation { held = $0 }
        }
        if let error = errors.removeValue(forKey: step) { throw error }
    }
}

@MainActor
struct CareCallViewModelTests {
    let service = FakePreparer()
    let viewModel: CareCallViewModel
    var state: CareCallScreenState { viewModel.preparation }

    init() {
        viewModel = CareCallViewModel(service: service)
    }

    private func waitUntilHolding() async {
        for _ in 0..<1_000 where !service.isHolding { await Task.yield() }
        #expect(service.isHolding)
    }

    @Test func 마이크_모델_음성인식_순서로_준비하고_끝나면_시작할_수_있다() async {
        #expect(state.preparation == .idle && !state.canStart)
        let task = viewModel.prepare()
        #expect(state.preparation == .preparing(.permissions) && state.isPreparing)
        await task?.value
        #expect(service.calls == [.microphone, .model, .speech])
        #expect(state.preparation == .ready)
        #expect(state.canStart && !state.isPreparing)
    }

    @Test func 단계마다_진행_상태를_보여_준다() async {
        service.hold = .speech
        let task = viewModel.prepare()
        await waitUntilHolding()
        #expect(state.preparation == .preparing(.speechAssets))
        service.release()
        await task?.value
        #expect(state.preparation == .ready)
    }

    @Test(arguments: [
        (FakePreparer.Step.microphone, AudioRecorderError.microphoneDenied as Error, CareCallPreparationState.microphoneDenied),
        (.model, LanguageModelError.modelMissing, .modelMissing),
        (.model, LanguageModelError.loadFailed(CancellationError()), .modelLoadFailed),
        (.speech, SpeechRecognizerError.koreanUnsupported, .speechRecognitionUnsupported),
        (.speech, SpeechRecognizerError.noAudioFormat, .failed),
    ])
    func 오류는_화면_상태로_바꾼다(step: FakePreparer.Step, error: Error, expected: CareCallPreparationState) async {
        service.errors[step] = error
        await viewModel.prepare()?.value
        #expect(state.preparation == expected)
        #expect(!state.canStart && !state.isPreparing)
    }

    @Test func 실패하면_다시_준비할_수_있다() async {
        service.errors[.model] = LanguageModelError.loadFailed(CancellationError())
        await viewModel.prepare()?.value
        #expect(state.preparation == .modelLoadFailed)
        await viewModel.prepare()?.value
        #expect(state.preparation == .ready)
        #expect(service.calls == [.microphone, .model, .microphone, .model, .speech])
    }

    @Test func 준비_중이거나_끝났으면_다시_불러도_한_번만_준비한다() async {
        service.hold = .model
        let task = viewModel.prepare()
        await waitUntilHolding()
        #expect(viewModel.prepare() == nil) // 앱으로 돌아와 다시 불림
        service.release()
        await task?.value
        #expect(viewModel.prepare() == nil) // 이미 준비됨
        #expect(service.calls == [.microphone, .model, .speech])
    }

    @Test func 준비_중에_화면을_떠나면_멈추고_처음_상태로() async {
        service.hold = .model
        let task = viewModel.prepare()
        await waitUntilHolding()
        state.onAction?(.cancel)
        #expect(state.preparation == .idle && !state.isPreparing)
        service.release()
        await task?.value
        #expect(state.preparation == .idle) // 늦게 끝난 이전 준비가 덮어쓰지 않음
        #expect(service.calls == [.microphone, .model])

        state.onAction?(.prepare) // 다시 들어오면 처음부터
        for _ in 0..<1_000 where state.preparation != .ready { await Task.yield() }
        #expect(state.preparation == .ready)
    }

    @Test func 떠났다_바로_돌아와도_이전_준비가_끝난_뒤에_서비스를_부른다() async {
        service.hold = .model // 모델을 불러오는 중에 떠남
        let first = viewModel.prepare()
        await waitUntilHolding()
        viewModel.cancelPreparation()
        let second = viewModel.prepare()
        #expect(state.preparation == .preparing(.permissions))
        for _ in 0..<100 { await Task.yield() }
        #expect(service.calls == [.microphone, .model]) // 이전 모델 불러오기가 끝나기 전엔 다시 부르지 않음
        service.release()
        await first?.value
        await second?.value
        #expect(service.calls == [.microphone, .model, .microphone, .model, .speech])
        #expect(state.preparation == .ready)
    }

    @Test func 준비가_끝난_뒤_떠나도_그대로() async {
        await viewModel.prepare()?.value
        state.onAction?(.cancel) // 전화를 받아 통화 화면으로 넘어갈 때도 불린다
        #expect(state.preparation == .ready && state.canStart)
    }
}
