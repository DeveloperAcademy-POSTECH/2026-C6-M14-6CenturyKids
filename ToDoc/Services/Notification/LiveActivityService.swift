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
            for await token in Activity<SymptomLiveActivityAttributes>.pushToStartTokenUpdates {
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

    #if DEBUG
    static func startLocalSymptomLiveActivity() throws {
        let attributes = SymptomLiveActivityAttributes(
            name: "Dr.속닥이",
            image: "LiveActivityHangno"
        )
        let content = ActivityContent(
            state: SymptomLiveActivityAttributes.ContentState(sentence: "오늘 하루는 어떠셨나요?"),
            staleDate: nil
        )
        _ = try Activity<SymptomLiveActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }
    #endif
    
    static func startPainLiveActivity() throws {
        try requestPainLiveActivity(attributes: .init(medicationTakenAt: .now))
    }

    static func startPainLiveActivity(for record: PainRecord, followUpAt: Date) async {
        let activities = Activity<PainLiveActivityAttributes>.activities
        let startedAt = Date.now
        if ActivityAuthorizationInfo().areActivitiesEnabled,
           !activities.contains(where: { $0.attributes.recordID == record.id }) {
            do {
                try requestPainLiveActivity(attributes: .init(
                    medicationTakenAt: startedAt < followUpAt ? startedAt : record.recordedDate,
                    recordID: record.id,
                    followUpAt: followUpAt
                ))
            } catch {
                print("통증 기록 Live Activity 시작 실패:", error)
            }
        }

        for activity in activities {
            guard let recordID = activity.attributes.recordID, recordID != record.id else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func endPainLiveActivity(recordID: UUID) async {
        for activity in Activity<PainLiveActivityAttributes>.activities
        where activity.attributes.recordID == recordID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func requestPainLiveActivity(attributes: PainLiveActivityAttributes) throws {
        let content = ActivityContent(
            state: PainLiveActivityAttributes.ContentState(),
            staleDate: attributes.timerEndsAt
        )

        _ = try Activity<PainLiveActivityAttributes>.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }
}
