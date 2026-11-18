import ActivityKit
import AppIntents
import SwiftUI

nonisolated enum LiveActivityDismissalStore {
    private static let prefix = "offline.dismissedPainActivity."
    static func dismiss(_ recordID: UUID) { UserDefaults.standard.set(true, forKey: prefix + recordID.uuidString) }
    static func isDismissed(_ recordID: UUID) -> Bool { UserDefaults.standard.bool(forKey: prefix + recordID.uuidString) }
}

/// Runs in the app process, closes just this activity, and leaves all health records intact.
struct DismissLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "실시간 현황 닫기"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @Parameter(title: "실시간 현황 ID") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }

    func perform() async throws -> some IntentResult {
        for activity in Activity<PainLiveActivityAttributes>.activities where activity.id == activityID {
            if let id = activity.attributes.recordID { LiveActivityDismissalStore.dismiss(id) }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        for activity in Activity<SymptomLiveActivityAttributes>.activities where activity.id == activityID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}

struct LiveActivityCloseButton: View {
    let activityID: String
    var body: some View {
        Button(intent: DismissLiveActivityIntent(activityID: activityID)) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("실시간 현황 닫기")
        .accessibilityHint("저장된 기록은 유지돼요")
        .accessibilityIdentifier("liveActivity.close")
    }
}
