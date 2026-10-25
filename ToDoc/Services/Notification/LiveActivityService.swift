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
        guard observationTask == nil else { return }
        
        observationTask = Task { [weak self] in
            for await token in Activity<ToDocWidgetExtensionAttributes>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                
                currentToken = token.map { String(format: "%02x", $0) }
                    .joined()
                
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
        guard let token = currentToken else { return }
        
        let userId = try await authRepository.getCurrentUserId()
        
        let tokenDTO = DeviceTokenDTO(userId: userId, installationId: InstallationId.value, updatedAt: .now, tokenType: .liveActivityStart, token: token, platform: "iOS")
        
        try await tokenRepository.save(token: tokenDTO)
    }
    
    func removeToken() async throws {
        let userId = try await authRepository.getCurrentUserId()
        
        try await tokenRepository.removeToken(userId: userId, installationId: InstallationId.value)
    }
}
