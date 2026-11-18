import Foundation

nonisolated enum LiveActivityDismissalStore {
    private static let prefix = "offline.dismissedPainActivity."
    static func dismiss(_ recordID: UUID) { UserDefaults.standard.set(true, forKey: prefix + recordID.uuidString) }
    static func isDismissed(_ recordID: UUID) -> Bool { UserDefaults.standard.bool(forKey: prefix + recordID.uuidString) }
}
