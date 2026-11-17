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

    private static let painCoordinator = SingleLiveActivityCoordinator()
    private static let symptomCoordinator = SingleLiveActivityCoordinator()
    // iPhone picks one of this app's activities for the Dynamic Island. Equal
    // scores keep the first activity there, even when a new pain timer starts.
    private static let painRelevanceScore: Double = 100
    private static let symptomRelevanceScore: Double = 10

    enum Failure: LocalizedError {
        case disabled
        var errorDescription: String? {
            "설정에서 속닥의 실시간 현황이 꺼져 있어요. 설정 → 앱 → 속닥 → 실시간 현황을 켜 주세요."
        }
    }

    static func startLocalSymptomLiveActivity() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        try await symptomCoordinator.run {
            // A manual test must not cancel the user's next scheduled reminder.
            for activity in Activity<SymptomLiveActivityAttributes>.activities where activity.activityState != .pending {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            _ = try Activity<SymptomLiveActivityAttributes>.request(
                attributes: .init(name: "Dr.속닥이", image: "LiveActivityHangno"),
                content: ActivityContent(state: .init(sentence: "오늘 하루는 어떠셨나요?"), staleDate: nil,
                                         relevanceScore: symptomRelevanceScore),
                pushType: nil
            )
        }
    }

    static func scheduleSymptomLiveActivity(at date: Date) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        let key = String(date.timeIntervalSince1970)
        try await symptomCoordinator.ensure(key: key, current: {
            // Keep the currently displayed conversation while reserving just one future activity.
            Activity<SymptomLiveActivityAttributes>.activities
                .filter { $0.activityState != .active && $0.activityState != .stale }
                .map {
                    .init(id: $0.id, key: String($0.attributes.scheduledFor?.timeIntervalSince1970 ?? -1),
                          isRunning: $0.activityState == .pending)
                }
        }, end: { id in
            for activity in Activity<SymptomLiveActivityAttributes>.activities where activity.id == id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }, start: {
            do {
                try requestScheduledSymptomActivity(at: date)
            } catch ActivityAuthorizationError.targetMaximumExceeded {
                try await Task.sleep(for: .milliseconds(500))
                try requestScheduledSymptomActivity(at: date)
            }
        })
    }

    private static func requestScheduledSymptomActivity(at date: Date) throws {
        _ = try Activity<SymptomLiveActivityAttributes>.request(
            attributes: .init(name: "Dr.속닥이", image: "LiveActivityHangno", scheduledFor: date),
            content: ActivityContent(state: .init(sentence: "오늘 하루는 어떠셨나요?"), staleDate: nil,
                                     relevanceScore: symptomRelevanceScore),
            pushType: nil,
            style: .standard,
            alertConfiguration: .init(title: "오늘의 증상을 기록해 주세요",
                                      body: "증상 대화를 시작해 볼까요?", sound: .default),
            start: date
        )
    }

    static func cancelSymptomLiveActivities() async {
        try? await symptomCoordinator.run {
            for activity in Activity<SymptomLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func startPainLiveActivity() async throws {
        try await ensurePainActivity(attributes: .init(medicationTakenAt: .now))
    }

    static func startPainLiveActivity(for record: PainRecord, followUpAt: Date) async throws {
        guard !LiveActivityDismissalStore.isDismissed(record.id) else { return }
        let startedAt = min(Date.now, record.recordedDate)
        try await ensurePainActivity(attributes: .init(medicationTakenAt: startedAt,
                                                       recordID: record.id, followUpAt: followUpAt))
    }

    private static func key(_ attributes: PainLiveActivityAttributes) -> String {
        "\(attributes.recordID?.uuidString ?? "test")/\(attributes.timerEndsAt.timeIntervalSince1970)"
    }

    private static func ensurePainActivity(attributes: PainLiveActivityAttributes) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        try await painCoordinator.ensure(key: key(attributes), current: {
            Activity<PainLiveActivityAttributes>.activities.map {
                .init(id: $0.id, key: key($0.attributes),
                      isRunning: $0.activityState == .active || $0.activityState == .stale)
            }
        }, end: { id in
            for activity in Activity<PainLiveActivityAttributes>.activities where activity.id == id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }, start: {
            if let id = attributes.recordID, LiveActivityDismissalStore.isDismissed(id) { return }
            do {
                try requestPainLiveActivity(attributes: attributes)
            } catch ActivityAuthorizationError.targetMaximumExceeded {
                // ActivityKit may briefly retain a slot after end() completes.
                try await Task.sleep(for: .milliseconds(500))
                try requestPainLiveActivity(attributes: attributes)
            }
        })
        await refreshPainActivityPriority()
    }

    static func endPainLiveActivity(recordID: UUID) async {
        try? await painCoordinator.run {
            for activity in Activity<PainLiveActivityAttributes>.activities
            where activity.attributes.recordID == recordID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Migrate already-running activities after an app update without creating
    /// another activity, changing the timer, or undoing a user's dismissal.
    static func refreshLiveActivityPriorities() async {
        await refreshPainActivityPriority()
        try? await symptomCoordinator.run {
            for activity in Activity<SymptomLiveActivityAttributes>.activities
            where (activity.activityState == .active || activity.activityState == .stale)
                && activity.content.relevanceScore != symptomRelevanceScore {
                await activity.update(ActivityContent(state: activity.content.state,
                                                       staleDate: activity.content.staleDate,
                                                       relevanceScore: symptomRelevanceScore))
            }
        }
    }

    private static func refreshPainActivityPriority() async {
        try? await painCoordinator.run {
            for activity in Activity<PainLiveActivityAttributes>.activities
            where (activity.activityState == .active || activity.activityState == .stale)
                && activity.content.relevanceScore != painRelevanceScore {
                await activity.update(ActivityContent(state: activity.content.state,
                                                       staleDate: activity.content.staleDate,
                                                       relevanceScore: painRelevanceScore))
            }
        }
    }

    /// Also removes legacy demo activities that have no record ID.
    static func endAllLiveActivities() async {
        try? await painCoordinator.run {
            for activity in Activity<PainLiveActivityAttributes>.activities {
                if let id = activity.attributes.recordID { LiveActivityDismissalStore.dismiss(id) }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            try? await symptomCoordinator.run {
                // Closing visible cards leaves future notification-time reservations intact.
                for activity in Activity<SymptomLiveActivityAttributes>.activities where activity.activityState != .pending {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    private static func requestPainLiveActivity(attributes: PainLiveActivityAttributes) throws {
        _ = try Activity<PainLiveActivityAttributes>.request(
            attributes: attributes,
            content: ActivityContent(state: .init(), staleDate: attributes.timerEndsAt,
                                     relevanceScore: painRelevanceScore),
            pushType: nil
        )
    }
}
