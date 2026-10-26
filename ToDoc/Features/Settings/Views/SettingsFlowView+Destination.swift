import SwiftUI

extension SettingsFlowView {
    enum Destination: String, Identifiable { case personal, cancer, stage, hospital, password, withdrawal; var id: String { rawValue } }
}
