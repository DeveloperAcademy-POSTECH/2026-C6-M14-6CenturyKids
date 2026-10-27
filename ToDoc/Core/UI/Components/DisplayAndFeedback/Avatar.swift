import SwiftUI

extension AppFeedback {
    /// Figma의 Avatar. 원본 캐릭터와 기분별 배경을 함께 표시합니다.
    struct Avatar: View {
        enum Mood: String, CaseIterable, Identifiable {
            case calm = "Calm"
            case worried = "Worried"
            case anxious = "Anxious"
            case notReady = "NotReady"
            case unsure = "Unsure"

            var id: Self { self }

            var accessibilityLabel: String {
                switch self {
                case .calm: "차분히 이야기를 들을 수 있어요"
                case .worried: "걱정되지만 듣고 싶어요"
                case .anxious: "걱정되는 마음이 커요"
                case .notReady: "마음의 준비가 더 필요해요"
                case .unsure: "아직 잘 모르겠어요"
                }
            }

            fileprivate var background: Color {
                switch self {
                case .calm: AppColors.Semantic.Avatar.calm
                case .worried: AppColors.Semantic.Avatar.worried
                case .anxious: AppColors.Semantic.Avatar.anxious
                case .notReady: AppColors.Semantic.Avatar.notReady
                case .unsure: AppColors.Semantic.Avatar.unsure
                }
            }
        }

        private let mood: Mood
        private let image: Image

        /// 교체 이미지는 Figma 마스크 영역으로 내보낸 40×37 비율을 사용합니다.
        init(
            mood: Mood,
            image: Image = Image("DesignSystem/Components/Feedback/AvatarDoctor")
        ) {
            self.mood = mood
            self.image = image
        }

        var body: some View {
            Circle()
                .fill(mood.background)
                .frame(width: 40, height: 40)
                .overlay(alignment: .bottom) {
                    image
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        // Figma에서 마스크로 잘린 원본 PNG를 그대로 배치합니다.
                        .frame(width: 40, height: 37)
                }
                .clipShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mood.accessibilityLabel)
        }
    }
}
