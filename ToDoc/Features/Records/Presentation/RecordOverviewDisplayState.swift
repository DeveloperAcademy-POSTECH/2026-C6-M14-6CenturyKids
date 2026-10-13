import Foundation

enum RecordOverviewDisplayState: Equatable {
    case idle, loading, loaded, unavailable, failed(String)
    var isLoaded: Bool { if case .loaded = self { true } else { false } }
}
