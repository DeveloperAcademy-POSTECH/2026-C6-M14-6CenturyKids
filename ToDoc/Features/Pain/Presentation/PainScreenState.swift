import Foundation
import Observation

/// 화면에 입력한 값 그대로 전달합니다. 검증·기록 생성·저장은 호수의 새 ViewModel 담당입니다.
struct PainFormInput {
    var locations: [BodyLocation] = []
    var before: Int?
    var after: Int?
}

/// 저장 결과를 화면에 표시할 때만 전달합니다. 이 타입은 저장 Model이 아닙니다.
struct PainCompletionData {
    let location: [BodyLocation]
    let painBefore: Int
    let painAfter: Int
    let painChange: Int
}

@Observable final class PainScreenState {
    var input = PainFormInput()
    var isSaving = false
    var errorMessage: String?
    var completion: PainCompletionData?
}
