import Foundation

/// Booth builds never initialize an analytics SDK or send events.
@MainActor
final class AmplitudeAnalytics {
    init(bundle: Bundle = .main) {}
    func track(_ eventName: String, properties: [String: Any] = [:]) {}
    func sendIntegrationTestIfRequested() {}
}
