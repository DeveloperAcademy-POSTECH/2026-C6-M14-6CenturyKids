import SwiftUI

struct OnboardingConversationView: View {
    var body: some View {
        OnboardingPageContent(
            title: "오늘의 몸 상태,\n말로 편하게 남겨요",
            description: "말한 내용은 글과 요약으로 정리돼요.\n저장 전에 확인하고 고칠 수 있어요."
        ) {
            ZStack(alignment: .topLeading) {
                OnboardingExampleImage(
                    name: "OnboardingConversationExample",
                    label: "음성 기록 예시. 오늘 아침부터 배가 조금 아팠어요라는 말이 배가 아파요로 정리돼요."
                )
                // 캐릭터는 원본 예시 그룹 밖의 별도 이미지입니다.
                Image("HakroDoctor")
                    .resizable().scaledToFit().frame(width: 76)
                    .offset(x: -12, y: -3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview { OnboardingConversationView().appScreenStyle() }
