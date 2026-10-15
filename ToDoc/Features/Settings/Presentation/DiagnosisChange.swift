import Foundation
import Observation

nonisolated enum DiagnosisChange: Equatable, Sendable {
    case carcinoma(CarcinomaType), stage(CarcinomaStage)
}
