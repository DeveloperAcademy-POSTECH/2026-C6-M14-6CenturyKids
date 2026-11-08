import Foundation
import Observation

/// 저장 결과를 화면에 표시할 때만 전달합니다. 이 타입은 저장 Model이 아닙니다.
struct PainCompletionData {
    let location: [BodyLocation]
    let painBefore: Int
    let painAfter: Int?
    let painChange: Int?
}

@Observable final class PainScreenState {
    var errorMessage: String?
    var completion: PainCompletionData?
}
