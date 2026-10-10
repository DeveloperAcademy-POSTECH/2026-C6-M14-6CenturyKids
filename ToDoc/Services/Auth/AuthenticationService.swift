//
//  AuthenticationService.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Foundation

final class AuthenticationService {
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let patientRepository: PatientRepository
    private let doctorRepository: DoctorRepository

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        patientRepository: PatientRepository,
        doctorRepository: DoctorRepository
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.patientRepository = patientRepository
        self.doctorRepository = doctorRepository
    }
    
    func signOut() async throws {
        try await authRepository.signOut()
    }

    func resetPassword(email: String) async throws {
        try await authRepository.resetPassword(email: email)
    }
}
