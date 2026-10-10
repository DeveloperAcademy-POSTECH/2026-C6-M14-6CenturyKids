//
//  AVAudioEngineAdapter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import AVFAudio

/// AVAudioEngine 마이크 입력. 녹음 파일 없이 마이크 소리를 실시간 버퍼로 넘긴다.
/// `@MainActor` 명시: Swift 5 모드에서 기본 격리만 받으면 @Sendable 클로저 저장 시 잘못된 경고가 난다
@MainActor
final class AVAudioEngineAdapter: AudioRecorder {
    var onEvent: ((AudioRecorderEvent) -> Void)?

    private let engine = AVAudioEngine()
    private let session = AVAudioSession.sharedInstance()
    /// 켜져 있는 동안만 값이 있다
    private var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?

    func prepare() async throws -> AVAudioFormat {
        guard await AVAudioApplication.requestRecordPermission() else { throw AudioRecorderError.microphoneDenied }
        // AI 음성(TTS)도 같은 세션으로 나오므로 듣기·말하기를 함께 쓰는 카테고리
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        return engine.inputNode.outputFormat(forBus: 0)
    }

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        self.onBuffer = onBuffer
        try startEngine()
    }

    func stop() {
        onBuffer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// 탭을 현재 입력 형식으로 다시 달고 엔진을 켠다 (장치가 바뀌면 형식도 바뀔 수 있다)
    private func startEngine() throws {
        guard let onBuffer else { return }
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        Self.installTap(on: input, format: input.outputFormat(forBus: 0), onBuffer: onBuffer)
        engine.prepare()
        try engine.start()
    }

    /// 탭 블록은 오디오 스레드에서 불리므로 MainActor 밖(nonisolated)에서 만든다.
    /// iOS 27에서 deprecated지만 대체 API(installTapOnBus:…:error:block:)가 아직 Swift 이름으로 노출되지 않아 그대로 쓴다
    private nonisolated static func installTap(
        on node: AVAudioInputNode, format: AVAudioFormat,
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void
    ) {
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in onBuffer(buffer) }
    }
}
