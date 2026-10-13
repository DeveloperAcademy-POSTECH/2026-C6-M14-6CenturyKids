import Foundation
import Observation

nonisolated enum SettingsLoadState: Equatable, Sendable {
    case idle, loading, loaded, unavailable, missingProfile, failed
}
