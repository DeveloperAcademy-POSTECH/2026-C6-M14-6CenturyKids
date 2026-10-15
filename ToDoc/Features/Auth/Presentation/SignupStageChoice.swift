#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

enum SignupStageChoice: Equatable {
    case known(CarcinomaStage), unknown, other
}
