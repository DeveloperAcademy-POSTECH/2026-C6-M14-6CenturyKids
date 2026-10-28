import SwiftUI

struct SignupStepScreen<Content: View>: View {
    @Bindable var state: SignupScreenState
    let title: String
    var buttonTitle = "다음"
    var subtitle: String? = nil
    var contentSpacing: CGFloat = 50
    @ViewBuilder var content: () -> Content

    var body: some View {
        AuthFormScreen(title: title, progress: state.step.progress,
                       onBack: { state.onAction?(.back) }, subtitle: subtitle, contentSpacing: contentSpacing) {
            content().disabled(state.isWorking || state.isAccountLocked)
            if state.hasAttemptedStep, let error = state.currentValidationError {
                AuthMessage(text: error)
            }
        } footer: {
            AppActions.Button(buttonTitle) { state.onAction?(.next) }
                .disabled(state.isWorking || state.onAction == nil)
        }
    }
}

struct SignupSummaryCard<Content: View>: View {
    let title: String
    let edit: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.content) {
            HStack {
                Text(title).appTextStyle(.label)
                Spacer()
                Button("수정", action: edit).appTextStyle(.caption)
                    .frame(minWidth: AppMetrics.Control.minimumHitSize, minHeight: AppMetrics.Control.minimumHitSize)
                    .accessibilityLabel("\(title) 수정")
            }
            content().appTextStyle(.label)
        }
        .padding(AppSpacing.Auth.informationPadding).frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(.authInformation)
    }
}
