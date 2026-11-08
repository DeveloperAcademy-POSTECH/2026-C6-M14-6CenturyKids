import SwiftUI

extension SettingsFlowView {
    enum Destination: String, Identifiable {
        case personal, cancer, stage, hospital, withdrawal
        case passwordCode, newPassword

        var id: String { rawValue }
    }
}
