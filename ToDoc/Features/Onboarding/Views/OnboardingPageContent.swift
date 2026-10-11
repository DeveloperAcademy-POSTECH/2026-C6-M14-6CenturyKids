import SwiftUI

/// 안내 문구는 Dynamic Type을 따르고, 기록 예시는 원본 비율을 유지합니다.
struct OnboardingPageContent<Illustration: View>: View {
    let title: String
    let description: String
    @ViewBuilder var illustration: Illustration

    @Environment(\.onboardingScrollsContent) private var scrollsContent

    var body: some View {
        if scrollsContent {
            GeometryReader { geometry in
                ScrollView { content(minHeight: geometry.size.height) }
            }
        } else {
            content(minHeight: 0)
        }
    }

    private func content(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.ButtonGroup.captionToButtons) {
            VStack(alignment: .leading, spacing: AppSpacing.ButtonGroup.captionToButtons) {
                Text(title)
                    .appTextStyle(.heading)
                    .foregroundStyle(AppColors.Text.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(description)
                    .appTextStyle(.label)
                    .foregroundStyle(AppColors.Text.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            illustration.frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }
}

struct OnboardingExampleImage: View {
    let name: String
    let label: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 322)
            .accessibilityLabel(label)
    }
}


extension EnvironmentValues {
    @Entry var onboardingScrollsContent = true
}
