import SwiftUI

extension SettingsFlowView {
    enum Destination: String, Identifiable { case personal, cancer, stage, hospital; var id: String { rawValue } }
}
