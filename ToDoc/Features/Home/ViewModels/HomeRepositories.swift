import Foundation
#if SWIFT_PACKAGE
import ToDocDomain
#endif

struct HomeRepositories {
    var patients: (any PatientRepository)?
    var doctors: (any DoctorRepository)?
    var notifications: (any NotificationRepository)?
    static let unavailable = HomeRepositories()
}
