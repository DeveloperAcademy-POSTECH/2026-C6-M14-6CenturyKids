import Foundation
import Observation

enum NotificationRowIcon: String {
    case doctor = "NotificationDoctor"
    case pain = "NotificationPainRecord"
    case symptom = "NotificationSymptomRecord"
}
struct NotificationRowData: Identifiable {
    let id: UUID
    let title: String
    let body: String
    let timeLabel: String
    let isRead: Bool
    var icon: NotificationRowIcon = .doctor
}
struct NotificationSectionData: Identifiable {
    let id: String
    let title: String
    let hasUnread: Bool
    let items: [NotificationRowData]
}
enum NotificationLoadState { case unavailable, loading, loaded, failed }
@Observable final class NotificationScreenState {
    var loadState: NotificationLoadState = .unavailable
    var sections: [NotificationSectionData] = []
    var errorMessage: String?
    var selectingID: UUID?
    @ObservationIgnored var onReload: (() -> Void)?
    @ObservationIgnored var onSelect: ((UUID) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
}
