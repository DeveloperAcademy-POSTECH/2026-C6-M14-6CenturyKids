//
//  LiveActivityService.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import ActivityKit
import Foundation

@MainActor
class LiveActivityService {
    private let tokenRepository: DeviceTokenRepository
    private let authRepository: AuthRepository
    private var currentToken: String?
    private var observationTask: Task<Void, Never>?
    
    init(tokenRepository: DeviceTokenRepository, authRepository: AuthRepository) {
        self.tokenRepository = tokenRepository
        self.authRepository = authRepository
    }
    
    func startObserving() {
        print("토큰 관찰 시작")
        guard observationTask == nil else { return }
        
        observationTask = Task { [weak self] in
            for await token in Activity<ToDocWidgetExtensionAttributes>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                
                currentToken = token.map { String(format: "%02x", $0) }
                    .joined()
                
                print("시작용 토큰 수신")
                
                do {
                    try await syncToken()
                } catch {
                    guard !Task.isCancelled else { return }
                    
                    print("Live Activity 토큰 동기화 실패", error)
                }
            }
        }
    }
    
    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
    
    func syncToken() async throws {
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        
        guard let token = currentToken else { return }
        
        let userId = try await authRepository.getCurrentUserId()
        print("사용자 조회 성공: ", userId)
        
        let tokenDTO = DeviceTokenDTO(userId: userId, installationId: InstallationId.value, tokenType: .liveActivityStart, token: token, platform: "iOS", environment: environment)
        
        try await tokenRepository.save(token: tokenDTO)
        print("DB 저장 성공")
    }
    
    func removeToken() async throws {
        let userId = try await authRepository.getCurrentUserId()
        
        try await tokenRepository.removeToken(userId: userId, installationId: InstallationId.value)
    }
    
    func testStartLiveActivity() async throws {
        try await tokenRepository.testStartLiveActivity()
    }
}
