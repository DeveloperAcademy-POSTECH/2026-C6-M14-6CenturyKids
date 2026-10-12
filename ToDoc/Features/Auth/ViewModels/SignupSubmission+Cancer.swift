import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

extension SignupSubmission {
    enum Cancer: Equatable, Sendable { case listed(CarcinomaType), other(String) }
}
