import SwiftUI

extension AppNavigation {
    struct ProgressBar: View {
        private let value: Double

        init(value: Double) {
            self.value = value
        }

        var body: some View {
            SwiftUI.ProgressView("진행률", value: fraction, total: 1)
                .progressViewStyle(TrackStyle())
        }

        private var fraction: Double {
            value.isFinite ? min(1, max(0, value)) : 0
        }

        private struct TrackStyle: ProgressViewStyle {
            func makeBody(configuration: Configuration) -> some View {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppColors.Semantic.Primary.default)
                        .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.Semantic.Background.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .frame(height: 16)
            }
        }
    }
}
