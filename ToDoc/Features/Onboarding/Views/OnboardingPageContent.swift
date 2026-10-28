import SwiftUI

/// 상단 탐색·하단 버튼은 부모가 담당하고, 소개 문구와 원본 이미지만 배치합니다.
struct OnboardingPageContent<Illustration: View>: View {
    let title: String
    let description: String
    @ViewBuilder var illustration: Illustration

    @Environment(\.onboardingScrollsContent) private var scrollsContent

    var body: some View {
        if scrollsContent {
            GeometryReader { geometry in
                ScrollView {
                    content(
                        topInset: min(108, max(24, geometry.size.height - 468)),
                        minHeight: geometry.size.height
                    )
                }
                .scrollIndicators(.hidden)
            }
        } else {
            // 큰 글자에서는 부모 ScrollView 하나로 제목부터 버튼까지 읽습니다.
            content(topInset: 24, minHeight: 0)
        }
    }

    private func content(topInset: CGFloat, minHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(title)
                    .appTypography(.headline)
                    .foregroundStyle(AppColors.Text.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(description)
                    // 원본 Caption은 14 Medium·Auto 행간·자간 0입니다.
                    .appTextStyle(.caption)
                    .foregroundStyle(AppColors.Text.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // Figma의 제목 y220 → 이미지 y379. 긴 문구는 이 높이를 넘어 확장합니다.
            .frame(maxWidth: .infinity, minHeight: 159, alignment: .top)

            illustration.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .padding(.top, topInset)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
    }
}

/// 네 소개 화면에 공통으로 배치된 Figma 원본 이미지입니다.
struct OnboardingDoctorIllustration: View {
    var body: some View {
        Image("OnboardingDoctor")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 260.725)
            .frame(maxWidth: .infinity)
            // 투명 여백을 포함한 원본 프레임의 중심이 화면 중심보다 11.365pt 오른쪽입니다.
            .padding(.leading, 22.73)
            .accessibilityHidden(true)
    }
}

extension EnvironmentValues {
    @Entry var onboardingScrollsContent = true
}
