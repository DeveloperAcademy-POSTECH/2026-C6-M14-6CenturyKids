//
//  AVAudioEngineAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import AVFAudio

/// AVAudioEngine 마이크 입력. 녹음 파일 없이 마이크 소리를 실시간 버퍼로 넘긴다.
final class AVAudioEngineAdapter: AudioRecorder {
    var onEvent: ((AudioRecorderEvent) -> Void)?

    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    /// 켜져 있는 동안만 값이 있다
    private var onBuffer: (@Sendable (AVReadOnlyAudioPCMBuffer) -> Void)?
    private var observers: [Any] = []

    func prepare() async throws -> AVAudioFormat {
        guard await AVAudioApplication.requestRecordPermission() else { throw AudioRecorderError.microphoneDenied }
        // AI 음성(TTS)도 같은 세션으로 나오므로 듣기·말하기를 함께 쓰는 카테고리
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        observeSystemEvents()
        return engine.inputNode.outputFormat(forBus: 0)
    }

    func start(onBuffer: @escaping @Sendable (AVReadOnlyAudioPCMBuffer) -> Void) throws {
        self.onBuffer = onBuffer
        try startEngine(onBuffer: onBuffer)
    }

    func stop() {
        onBuffer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// 탭을 현재 입력 형식으로 다시 달고 엔진을 켠다 (장치가 바뀌면 형식도 바뀔 수 있다)
    private func startEngine(onBuffer: @escaping @Sendable (AVReadOnlyAudioPCMBuffer) -> Void) throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        // 탭 콜백은 오디오 스레드에서 불린다 (@Sendable 클로저라 MainActor에 묶이지 않음)
        try input.installAudioTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { buffer, _ in
            onBuffer(buffer)
        }
        engine.prepare()
        try engine.start()
    }

    /// 오디오 중단(전화·Siri)과 장치 변경(이어폰·블루투스)을 처리한다. 한 번만 등록한다
    private func observeSystemEvents() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(of: session, for: .didBecomeInactive) { [weak self] message in
                guard case .systemInterruption = message.deactivationResult else { return }
                self?.onEvent?(.interrupted)
            },
            center.addObserver(of: session, for: .resumptionRecommendation) { [weak self] message in
                guard message.recommendation == .shouldResume else { return }
                self?.resumeAfterInterruption()
            },
            // 장치가 바뀌면 엔진이 멈추고 입력 형식이 달라질 수 있어 탭을 다시 단다
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.restartAfterConfigurationChange() }
            },
        ]
    }

    private func resumeAfterInterruption() {
        // 마이크가 꺼져 있었으면(stop 후) 다시 켜지 않는다
        guard let onBuffer else { return }
        do {
            try session.setActive(true)
            try startEngine(onBuffer: onBuffer)
            onEvent?(.resumed)
        } catch {
            onEvent?(.failed(error))
        }
    }

    private func restartAfterConfigurationChange() {
        // 마이크가 꺼져 있었으면(stop 후) 다시 켜지 않는다
        guard let onBuffer else { return }
        do {
            try startEngine(onBuffer: onBuffer)
        } catch {
            onEvent?(.failed(error))
        }
    }
}
