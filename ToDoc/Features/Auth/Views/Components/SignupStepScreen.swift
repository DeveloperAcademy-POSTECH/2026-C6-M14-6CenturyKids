import SwiftUI

struct SignupStepScreen<Content: View>: View {
    @Bindable var model: SignupViewModel
    let title: String
    var buttonTitle = "다음"
    @ViewBuilder var content: () -> Content

    var body: some View {
        AuthFormScreen(title: title, progress: model.step.progress, onBack: { model.back() }) {
            content()
            if model.hasAttemptedStep, let error = model.currentValidationError {
                AuthMessage(text: error)
            }
        } footer: {
            Button(buttonTitle) { model.next() }
                .buttonStyle(AppButtonStyle()).disabled(model.isWorking)
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
