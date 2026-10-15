//
//  SpeechSynthesizer.swift
//  ToDoc
//
//  Created by seokho on 10/10/26.
//


/// 음성 합성. 케어콜에서 질문 문장을 읽어 줄 때 쓴다.
/// 한 번에 한 문장씩: 다음 `speak` 전에 `waitUntilDone()`으로 앞의 말이 끝나기를 기다린다.
protocol SpeechSynthesizer: AnyObject {
    /// 말하기를 시작하고, 소리가 나기 시작하면 돌아온다 (말하는 동안 다른 일을 할 수 있게)
    func speak(_ text: String) async

    /// 지금 하는 말이 끝날 때까지 기다린다. 말하는 중이 아니면 바로 돌아온다
    func waitUntilDone() async

    func stop()

    /// 앞으로 말할 고정 문구를 뒤에서 미리 합성해 둔다 (합성이 느린 구현만)
    func preload(_ texts: [String])

    /// 다른 무거운 작업(모델 분석) 동안 미리 합성을 멈춘다
    func setBusy(_ busy: Bool) async
}

extension SpeechSynthesizer {
    func preload(_ texts: [String]) {}
    func setBusy(_ busy: Bool) async {}
}
