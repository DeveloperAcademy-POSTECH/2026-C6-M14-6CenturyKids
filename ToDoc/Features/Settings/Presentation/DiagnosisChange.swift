import Foundation
import Observation

nonisolated enum DiagnosisChange: Equatable, Sendable {
    case carcinoma(CarcinomaType, otherName: String? = nil), stage(CarcinomaStage)
}
