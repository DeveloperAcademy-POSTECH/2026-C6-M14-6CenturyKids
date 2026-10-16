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
    
    /// 현재 로그인된 사용자의 정보를 반환합니다.
    func getCurrentUserId() async throws -> UUID? {
        return try await authRepository.getCurrentUserId()
    }
    
    /// 환자 계정으로 인증한 후 환자 정보를 조회해 반환합니다.
    func signInPatient(
        email: String,
        password: String
    ) async throws -> Patient {
        let userId = try await authRepository.signIn(
            email: email,
            password: password
        )
        
        guard let user = try await userRepository.findById(userId) else{
            // Core/Errors 에러 타입 확정 후 throw 구현 필요
            fatalError("User 조회 실패 에러 타입 확정 필요")
        }
        
        guard let patient = try await patientRepository.findById(user.id) else {
            // 에러 타입 확정 후 throw 구현 필요
            fatalError("Patient 조회 실패 에러 타입 확정 필요")
        }
        
        return patient
    }
    
    /// 의사 계정으로 인증한 후 해당 의사 정보를 조회해 Domain 객체를 반환합니다.
    func signInDoctor(
        email: String,
        password: String
    ) async throws -> Doctor {
        let userId = try await authRepository.signIn(
            email: email,
            password: password
        )
        
        guard let user = try await userRepository.findById(userId) else {
            // Core/Errors 에러 타입 확정 후 throw 구현 필요
            fatalError("User 조회 실패 에러 타입 확정 필요")
        }
        
        guard let doctor = try await doctorRepository.findById(userId) else {
            // 에러 타입 확정 후 throw 구현 필요
            fatalError("Doctor 조회 실패 에러 타입 확정 필요")
        }
        
        return doctor
    }
    
    /// 환자, 의사 회원가입은 생성자 확인 후 추후 구현 예정입니다.
    func signUpPatient(
        email: String,
        password: String,
        name: String,
        birthday: Date,
        sex: Sex,
        carcinomaType: CarcinomaType?,
        stage: CarcinomaStage?,
        doctorCode: String?
    ) async throws -> Patient {
        /// User, Patient 생성자 확인 후 구현
        fatalError("Patient Domain 생성자 확정 후 구현")
    }
    
    func signUpDoctor(
        email: String,
        password: String,
        name: String,
        birthday: Date,
        sex: Sex,
        hospitalCode: String
    ) async throws -> Doctor {
        /// User, Doctor, Hospital 생성자 확인후 구현
        fatalError("Doctor Domain 생성자 확정 후 구현")
    }
}

