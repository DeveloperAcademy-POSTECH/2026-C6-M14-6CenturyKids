import SwiftUI

struct SignupStepScreen<Content: View>: View {
    @Bindable var state: SignupScreenState
    let title: String
    var buttonTitle = "다음"
    @ViewBuilder var content: () -> Content

    var body: some View {
        AuthFormScreen(title: title, progress: state.step.progress, onBack: { state.onAction?(.back) }) {
            content()
            if state.hasAttemptedStep, let error = state.currentValidationError {
                AuthMessage(text: error)
            }
        } footer: {
            Button(buttonTitle) { state.onAction?(.next) }
                .buttonStyle(AppButtonStyle()).disabled(state.isWorking || state.onAction == nil)
        }
    }
}

struct SignupSummaryCard<Content: View>: View {
    let title: String
    let edit: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).appTextStyle(.label)
                Spacer()
                Button("수정", action: edit).appTextStyle(.caption)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("\(title) 수정")
            }
            content().appTextStyle(.label)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 20))
    }
}
