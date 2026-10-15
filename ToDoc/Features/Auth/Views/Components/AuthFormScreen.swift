import SwiftUI

/// 키보드·작은 화면·큰 글자에서도 본문과 CTA에 접근할 수 있는 가입 화면 틀.
struct AuthFormScreen<Content: View, Footer: View>: View {
    let title: String
    var progress: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    if let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("이전 단계")
                    }
                    Spacer()
                    Text(progress ?? "C6").appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                }
                Text(title).appTextStyle(.heading)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) { footer() }
                .padding(.vertical, 12)
                .background(AppColors.background)
        }
        .appScreenStyle()
        .foregroundStyle(AppColors.Text.primary)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct AuthMessage: View {
    let text: String
    var isError = true

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
            .appTextStyle(.caption)
            .foregroundStyle(isError ? Color.red : AppColors.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

struct AuthSubmitLabel: View {
    let title: String
    let isLoading: Bool
    var body: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().tint(AppColors.Text.primary) }
            Text(isLoading ? "처리 중이에요" : title)
        }
    }
}
