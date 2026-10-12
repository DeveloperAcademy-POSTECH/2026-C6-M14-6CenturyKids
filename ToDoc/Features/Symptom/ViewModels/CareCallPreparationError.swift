/// 서비스 연결부가 화면에 전달하는 준비 실패입니다. 권한 요청 자체는 담당하지 않습니다.
nonisolated enum CareCallPreparationError: Error, Equatable, Sendable {
    case microphoneDenied
    /// 시뮬레이터 또는 앱 번들에 모델이 없는 경우. 서비스 미연결과 구분합니다.
    case modelMissing
    /// 모델은 있으나 로드하지 못한 경우. 내부 오류 원문은 화면에 노출하지 않습니다.
    case modelLoadFailed
    case speechRecognitionUnsupported
    case unavailable
}
