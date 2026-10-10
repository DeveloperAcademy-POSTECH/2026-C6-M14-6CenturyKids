//
//  SpeechRecognizer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

/// 음성 인식. 케어콜에서 환자가 한 말을 글자로 바꿀 때 쓴다.
protocol SpeechRecognizer: AnyObject {
    /// 한국어 인식기와 마이크를 준비하고 인식을 시작한다. 처음 한 번 한국어 인식 에셋을 내려받는다 (네트워크 사용)
    func prepare() async throws

    /// 환자 말 한 턴을 듣는다. 말이 끝나면(확정 결과 뒤 무음) 문장을 돌려주고, 그 전에 정지되면 그때까지 들은 문장을 돌려준다.
    func listen() async -> String

    func stop() async
}
