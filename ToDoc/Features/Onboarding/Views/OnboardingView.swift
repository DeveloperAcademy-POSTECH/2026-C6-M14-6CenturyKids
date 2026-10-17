import SwiftUI

@MainActor struct OnboardingView: View {
    @State private var model: AuthFlowViewModel
    init(model: AuthFlowViewModel? = nil) {
        _model = State(initialValue: model ?? AuthFlowViewModel())
    }
    private var page: Int { model.onboarding.page }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: AppSpacing.ButtonGroup.captionToButtons) {
                            header
                            selectedPage
                                .environment(\.onboardingScrollsContent, false)
                            footer
                        }
                    }
                    .id(page)
                } else {
                    VStack(spacing: AppSpacing.ButtonGroup.captionToButtons) {
                        header
                        TabView(selection: Binding(get: { page }, set: { model.onboarding.selectPage($0) })) {
                            welcome.tag(0)
                            OnboardingDailyCareView().tag(1)
                            OnboardingConversationView().tag(2)
                            OnboardingRecordTypesView().tag(3)
                            OnboardingHistoryView().tag(4)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        footer
                    }
                }
            }
            .padding(.vertical, 8)
            .appScreenStyle()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $model.showsAuth) {
                AuthFlowView(model: model, onClose: model.close)
            }
        }
    }

    @ViewBuilder private var selectedPage: some View {
        switch page {
        case 0: welcome
        case 1: OnboardingDailyCareView()
        case 2: OnboardingConversationView()
        case 3: OnboardingRecordTypesView()
        default: OnboardingHistoryView()
        }
    }

    private var header: some View {
        HStack {
            if page == 0 {
                Text("C6")
                    .appTextStyle(.heading)
                    .foregroundStyle(AppColors.Button.primaryForeground)
                Spacer()
            } else {
                HStack(spacing: 0) {
                    ForEach(1...4, id: \.self) { index in
                        Button {
                            selectPage(index)
                        } label: {
                            Circle()
                                .fill(page == index ? AppColors.gray : AppColors.secondary)
                                .frame(width: 12, height: 12)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("소개 \(index), 4페이지 중 \(index)페이지")
                        .accessibilityAddTraits(page == index ? .isSelected : [])
                    }
                }
                Spacer(minLength: 0)
                Button("건너뛰기", action: openSignup)
                    .appTextStyle(.caption)
                    .foregroundStyle(AppColors.Text.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .frame(minHeight: 44)
    }

    private var welcome: some View {
        OnboardingPageContent(
            title: "오늘의 몸 상태를\n편하게 기록해요",
            description: "통증과 증상을\n한곳에서 기록할 수 있어요."
        ) {
            Image("HakroDoctor")
                .resizable().scaledToFit().frame(maxWidth: 230)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.ButtonGroup.verticalGap) {
            if let error = model.onboarding.errorMessage { AuthMessage(text: error) }
            Button(page == 4 ? "회원가입" : "시작하기") {
                if page == 0 { selectPage(1) }
                else { openSignup() }
            }
            .buttonStyle(AppButtonStyle())
            if page == 4 {
                // Apple 인증 Repository 연결이 연결되기 전에는 요청을 보내지 않습니다.
                Button {} label: {
                    HStack {
                        Image("OnboardingApple")
                            .resizable().scaledToFit().frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                        Text("Apple로 로그인 · 준비 중")
                    }
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))
                .disabled(true)
            }
            Button(action: openLogin) {
                Text("이미 계정이 있나요? 로그인")
                    .appTextStyle(.caption)
                    .underline()
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(AppColors.Text.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func openSignup() {
        model.open(.signup)
    }

    private func openLogin() {
        model.open(.login)
    }

    private func selectPage(_ index: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { model.onboarding.selectPage(index) }
    }
}

#Preview { OnboardingView() }
