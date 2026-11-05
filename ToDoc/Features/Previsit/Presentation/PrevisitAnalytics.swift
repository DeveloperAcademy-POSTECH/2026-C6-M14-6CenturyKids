import Foundation

/// 초안과 함께 유지되는 작성 시도별 계측 상태입니다.
struct PrevisitAnalytics {
    typealias Track = @MainActor (String, [String: Any]) -> Void

    struct Attempt {
        let id = UUID()
        var moodVisitID: UUID?
        var moodChangeCount = 0
        var activeDuration: Duration = .zero
    }

    let track: Track?
    private(set) var attempt: Attempt?

    init(track: Track? = nil) {
        self.track = track
    }

    mutating func beginAttemptIfNeeded() {
        guard track != nil, attempt == nil else { return }
        attempt = Attempt()
    }

    mutating func resetAttempt() {
        attempt = nil
    }
}
