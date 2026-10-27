import SwiftUI

/// 키보드·작은 화면·큰 글자에서도 본문과 CTA에 접근할 수 있는 가입 화면 틀.
struct AuthFormScreen<Content: View, Footer: View>: View {
    @State private var inputDismissal = 0
    let title: String
    var progress: String? = nil
    var onBack: (() -> Void)? = nil
    var subtitle: String? = nil
    var contentSpacing: CGFloat = 50
    var keyboardFooterBehavior: AuthKeyboardFooterBehavior = .keepActions
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if let onBack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(AppActions.PressStyle())
                            .accessibilityLabel("이전 단계")
                        }
                        Spacer()
                    }
                    .frame(minHeight: 44)
                    .padding(.top, 8)

                    if let progress {
                        progressLabel(progress)
                            .padding(.top, max(16, 147 - geometry.safeAreaInsets.top - 52))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).appTypography(.titleLarge)
                            .accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle).appFont(.settingsCaption)
                                .foregroundStyle(AppColors.Semantic.Text.disabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, progress == nil
                             ? max(24, 220 - geometry.safeAreaInsets.top - 52) : 47)

                    VStack(alignment: .leading, spacing: 20) { content() }
                        .padding(.top, contentSpacing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AuthKeyboardFooter(behavior: keyboardFooterBehavior, onDismiss: { inputDismissal &+= 1 }) { footer() }
        }
        .environment(\.authInputDismissal, inputDismissal)
        .background(AppColors.Semantic.Background.surface.ignoresSafeArea())
        .foregroundStyle(AppColors.Semantic.Text.default)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func progressLabel(_ progress: String) -> some View {
        let count = progress.split(separator: " ").last.map(String.init) ?? progress
        let parts = count.split(separator: "/").compactMap { Double($0) }
        let fraction = parts.count == 2 && parts[1] > 0 ? min(max(parts[0] / parts[1], 0), 1) : nil

        return VStack(alignment: .leading, spacing: 6) {
            Text(fraction == nil ? progress : count)
                .appTypography(.caption)
                .foregroundStyle(AppColors.Semantic.Text.disabled)
            if let fraction {
                GeometryReader { geometry in
                    Capsule().fill(AppColors.Semantic.Border.default)
                        .overlay(alignment: .leading) {
                            Capsule().fill(AppColors.Semantic.Primary.default)
                                .frame(width: geometry.size.width * fraction)
                        }
                }
                .frame(width: 110, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress)
    }
}

enum AuthKeyboardFooterBehavior {
    case keepActions
    case compact
}

/// 기본은 키보드 위 액션을 유지하고, 입력 공간이 필요한 화면만 작은 완료 버튼을 쓴다.
struct AuthKeyboardFooter<Content: View>: View {
    var behavior: AuthKeyboardFooterBehavior = .keepActions
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var isKeyboardVisible = false

    private var showsCompactFooter: Bool { isKeyboardVisible && behavior == .compact }

    var body: some View {
        VStack(spacing: 20) {
            if showsCompactFooter {
                HStack {
                    Spacer()
                    Button("입력 완료", action: onDismiss)
                        .appTypography(.label)
                        .frame(minHeight: AppMetrics.Control.minimumHitSize)
                }
            } else {
                content()
            }
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .padding(.top, showsCompactFooter ? 0 : 16)
        .background(AppColors.Semantic.Background.surface)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            isKeyboardVisible = frame.height > 0
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onDisappear { isKeyboardVisible = false }
    }
}

struct AuthMessage: View {
    let text: String
    var isError = true

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
            .appTypography(.bodySmall)
            .foregroundStyle(isError ? AppColors.Semantic.Text.error : AppColors.Semantic.Text.sub)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }
}

struct AuthSubmitLabel: View {
    let title: String
    let isLoading: Bool
    var body: some View {
        HStack(spacing: 8) {
            if isLoading { ProgressView().tint(AppColors.Semantic.Text.onPrimary) }
            Text(isLoading ? "처리 중이에요" : title)
        }
    }
}
