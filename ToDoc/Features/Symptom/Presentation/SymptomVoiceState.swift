import Foundation

/// 음성 증상 대화에서 지금 누구 차례인지. 화면은 이 값으로 캐릭터 영상을 고른다
enum SymptomVoiceState: Sendable {
    /// AI 음성(TTS)이 질문을 말하는 중
    case aiSpeaking
    /// 환자 차례. 마이크가 듣는 중이며 아직 말을 시작하지 않았어도 여기
    case patientSpeaking
    /// AI 모델이 답을 분석하거나 첫 질문을 준비하는 중
    case thinking
}
