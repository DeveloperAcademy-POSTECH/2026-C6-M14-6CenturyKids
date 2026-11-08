nonisolated enum CareCallPreparationPhase: Sendable {
    case permissions
    case model
    /// 확인·설치·인식기 준비를 포함합니다. 다운로드 백분율을 뜻하지 않습니다.
    case speechAssets
}
