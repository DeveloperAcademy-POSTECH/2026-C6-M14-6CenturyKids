import SwiftUI

extension SettingsFlowView {
    enum Destination: String, Identifiable {
        case personal, cancer, stage, hospital
        case passwordCode, newPassword

        var id: String { rawValue }
    }
}
