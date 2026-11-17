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
    
    func startObserving() {}
    func stopObserving() {}
    func syncToken() async throws {}

    func removeToken() async throws {
        let userId = try await authRepository.getCurrentUserId()
        
        try await tokenRepository.removeToken(userId: userId, installationId: InstallationId.value)
    }
    
    func testStartLiveActivity() async throws {
        try await tokenRepository.testStartLiveActivity()
    }

    private static let painCoordinator = SingleLiveActivityCoordinator()

    enum Failure: LocalizedError {
        case disabled
        var errorDescription: String? {
            "설정에서 속닥의 실시간 현황이 꺼져 있어요. 설정 → 앱 → 속닥 → 실시간 현황을 켜 주세요."
        }
    }

    static func startLocalSymptomLiveActivity() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Failure.disabled }
        for activity in Activity<SymptomLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        _ = try Activity<SymptomLiveActivityAttributes>.request(
            attributes: .init(name: "Dr.속닥이", image: "LiveActivityHangno"),
            content: ActivityContent(state: .init(sentence: "오늘 하루는 어떠셨나요?"), staleDate: nil),
            pushType: nil
        )
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
    }

    static func endPainLiveActivity(recordID: UUID) async {
        try? await painCoordinator.run {
            for activity in Activity<PainLiveActivityAttributes>.activities
            where activity.attributes.recordID == recordID {
                await activity.end(nil, dismissalPolicy: .immediate)
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
            for activity in Activity<SymptomLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func requestPainLiveActivity(attributes: PainLiveActivityAttributes) throws {
        _ = try Activity<PainLiveActivityAttributes>.request(
            attributes: attributes,
            content: ActivityContent(state: .init(), staleDate: attributes.timerEndsAt),
            pushType: nil
        )
    }
}
