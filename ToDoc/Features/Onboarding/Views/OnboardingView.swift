import SwiftUI

@MainActor struct OnboardingView: View {
    @State private var viewModel: AuthFlowViewModel
    init(viewModel: AuthFlowViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    private var page: Int { viewModel.onboarding.page }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 0) {
                            header
                            selectedPage
                                .environment(\.onboardingScrollsContent, false)
                            footer
                        }
                    }
                    .id(page)
                } else {
                    VStack(spacing: 0) {
                        header
                        TabView(selection: Binding(get: { page }, set: { viewModel.onboarding.selectPage($0) })) {
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
            .padding(.top, 6)
            .background(AppColors.Semantic.Background.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $viewModel.showsAuth) {
                AuthFlowView(viewModel: viewModel, onClose: viewModel.close)
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 56, height: 44)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if page > 0 { pageButtons }
                Spacer(minLength: 0)
                skipLink
            }
            VStack(spacing: 0) {
                HStack { Spacer(); skipLink }
                if page > 0 { pageButtons }
            }
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .frame(minHeight: 44)
    }

    private var pageButtons: some View {
        HStack(spacing: 0) {
            ForEach(1...4, id: \.self) { index in
                Button { selectPage(index) } label: {
                    Capsule()
                        .fill(page == index ? AppColors.Semantic.Primary.default : AppColors.Semantic.Border.default)
                        .frame(width: page == index ? 15 : 7, height: 7)
                        .padding(.horizontal, 3)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("소개 \(index), 4페이지 중 \(index)페이지")
                .accessibilityAddTraits(page == index ? .isSelected : [])
            }
        }
    }

    private var skipLink: some View {
        Button("건너뛰기", action: openLogin)
            .appTextStyle(.caption)
            .foregroundStyle(AppColors.Semantic.Text.disabled)
            .frame(minWidth: 56, minHeight: 44, alignment: .trailing)
            .opacity(page > 0 ? 1 : 0)
            .disabled(page == 0)
            .accessibilityHidden(page == 0)
    }

    private var welcome: some View {
        OnboardingPageContent(
            title: "오늘의 몸 상태를\n편하게 기록해요",
            description: "통증과 증상을\n한곳에서 기록할 수 있어요."
        ) {
            OnboardingDoctorIllustration()
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let error = viewModel.onboarding.errorMessage { AuthMessage(text: error) }
            AppActions.Button(page == 0 ? "시작하기" : "다음") {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    viewModel.advanceOnboarding()
                }
            }
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
    }

    private func openLogin() {
        viewModel.open(.login)
    }

    private func selectPage(_ index: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { viewModel.onboarding.selectPage(index) }
    }
}

#Preview { OnboardingView(viewModel: AuthFlowViewModel(session: AuthSessionState())) }
