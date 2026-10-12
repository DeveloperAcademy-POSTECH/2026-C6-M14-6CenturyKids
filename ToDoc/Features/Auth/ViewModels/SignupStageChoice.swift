import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

enum SignupStageChoice: Equatable {
    case known(CarcinomaStage), unknown, other
}
