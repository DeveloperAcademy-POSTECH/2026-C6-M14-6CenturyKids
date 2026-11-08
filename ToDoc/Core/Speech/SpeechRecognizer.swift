//
//  SpeechRecognizer.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

/// 음성 인식. 케어콜에서 환자가 한 말을 글자로 바꿀 때 쓴다.
protocol SpeechRecognizer: AnyObject {
    /// 마이크 권한을 받고 한국어 인식기를 준비한다. 처음 한 번 한국어 인식 에셋을 내려받는다 (네트워크 사용)
    func prepare() async throws

    /// 마이크를 켠다 (준비 뒤, 통화를 시작할 때). 듣는 중이 아닐 때 들어온 소리는 버린다. 이미 켜져 있으면 그대로
    func startMicrophone() throws

    /// 환자 말 한 턴을 듣는다 (마이크가 꺼져 있으면 켠다). 말이 끝나면(확정 결과 뒤 무음) 문장을 돌려주고,
    /// 그 전에 정지되면 그때까지 들은 문장을 돌려준다. 마이크를 켜지 못하면 에러.
    /// 듣는 동안 지금까지 들은 말(아직 바뀔 수 있는 중간 결과 포함)을 onPartial로 알린다
    func listen(onPartial: @escaping (String) -> Void) async throws -> String

    func stop() async
}
