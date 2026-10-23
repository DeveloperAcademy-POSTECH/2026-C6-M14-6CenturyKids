#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

enum SignupStageChoice: Equatable {
    case known(CarcinomaStage), unknown

    var domainValue: CarcinomaStage {
        switch self {
        case .known(let stage): stage
        case .unknown: .unknown
        }
    }
}
