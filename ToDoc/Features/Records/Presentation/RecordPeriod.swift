import Foundation

nonisolated enum RecordPeriod: String, CaseIterable, Sendable {
    case month, week, day
    var displayName: String { switch self { case .month: "월"; case .week: "주"; case .day: "일" } }
    var component: Calendar.Component { switch self { case .month: .month; case .week: .weekOfYear; case .day: .day } }
}
