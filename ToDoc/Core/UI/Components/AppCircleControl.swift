import SwiftUI

struct AppCircleControl: View {
    let title: String
    let asset: String
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            VStack(spacing: AppSpacing.compact) {
                Image(asset)
                    .frame(width: AppMetrics.Conversation.controlIconSize, height: AppMetrics.Conversation.controlIconSize)
                    .frame(width: AppMetrics.Conversation.controlSize, height: AppMetrics.Conversation.controlSize)
                    .background(AppColors.Surface.control, in: Circle())
                    .accessibilityHidden(true)
                Text(title).appFont(.controlCaption)
                    .foregroundStyle(AppColors.Text.control)
            }
        }
        .buttonStyle(AppPressStyle())
        .disabled(action == nil)
    }
}
