//
//  CareCallViewModel.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

import Foundation

/// 케어콜 화면(CareCallFlowView)의 상태를 보관한다. 지금은 준비(마이크 권한 → AI 모델 → 한국어 음성 인식)만 연결한다.
/// 준비한 서비스는 이어지는 통화에서 그대로 쓴다
@MainActor
final class CareCallViewModel {
    let preparation = CareCallScreenState()
    private let service: any CareCallPreparing
    /// 지금 진행 중인 준비 (없으면 준비 중이 아님)
    private var preparing: Task<Void, Never>?
    /// 마지막으로 시작한 준비. 취소해도 서비스 작업(모델 불러오기 등)은 끝까지 돌기 때문에 다음 준비는 이게 끝난 뒤 시작한다
    private var last: Task<Void, Never>?
    /// 준비 요청마다 늘린다. 취소·재시도 뒤에 늦게 끝난 이전 준비가 상태를 덮어쓰지 않게
    private var generation = 0

    init(service: any CareCallPreparing) {
        self.service = service
        show(.idle)
        preparation.onAction = { [weak self] action in
            switch action {
            case .prepare: self?.prepare()
            case .cancel: self?.cancelPreparation()
            }
        }
    }

    /// 대기 화면이 보일 때마다(앱으로 돌아올 때 포함) 불린다. 준비 중이거나 이미 끝났으면 그대로 두고,
    /// 실패했으면 처음 단계부터 다시 한다 (서비스가 끝난 단계는 건너뛴다)
    @discardableResult
    func prepare() -> Task<Void, Never>? {
        guard preparing == nil, preparation.preparation != .ready else { return nil }
        generation += 1
        let current = generation
        show(.preparing(.permissions))
        let previous = last
        let task = Task {
            // 화면을 떠났다 바로 돌아오면 취소한 준비가 아직 모델을 불러오는 중일 수 있다 (2.4GB를 두 번 불러오지 않게)
            await previous?.value
            do {
                try advance(to: .preparing(.permissions), current)
                try await service.requestMicrophone()
                try advance(to: .preparing(.model), current)
                try await service.loadModel()
                try advance(to: .preparing(.speechAssets), current)
                try await service.prepareSpeech()
                try advance(to: .ready, current)
            } catch {
                guard current == generation else { return } // 취소했거나 새 준비가 시작됨
                show(Self.state(for: error))
            }
            if current == generation { preparing = nil }
        }
        preparing = task
        last = task
        return task
    }

    /// 대기 화면을 떠날 때 불린다. 준비 중이면 멈추고 처음 상태로 돌린다.
    /// 준비가 끝났으면 그대로 둔다 (전화를 받아 통화 화면으로 넘어갈 때도 불린다)
    func cancelPreparation() {
        guard let preparing else { return }
        generation += 1
        preparing.cancel()
        self.preparing = nil
        show(.idle)
    }

    private func advance(to state: CareCallPreparationState, _ current: Int) throws {
        try Task.checkCancellation()
        guard current == generation else { throw CancellationError() }
        show(state)
    }

    private func show(_ state: CareCallPreparationState) {
        preparation.preparation = state
        if case .preparing = state { preparation.isPreparing = true } else { preparation.isPreparing = false }
        preparation.canStart = state == .ready
    }

    /// 준비 오류 → 화면 상태. 원래 오류 문구는 화면에 내보내지 않는다
    private static func state(for error: Error) -> CareCallPreparationState {
        switch error {
        case AudioRecorderError.microphoneDenied: .microphoneDenied
        case LanguageModelError.modelMissing: .modelMissing
        case LanguageModelError.loadFailed: .modelLoadFailed
        case SpeechRecognizerError.koreanUnsupported: .speechRecognitionUnsupported
        default: .failed
        }
    }
}
