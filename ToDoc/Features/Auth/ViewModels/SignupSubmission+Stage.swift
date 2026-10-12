import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

extension SignupSubmission {
    enum Stage: Equatable, Sendable { case known(CarcinomaStage), unknown, other(String) }
}
