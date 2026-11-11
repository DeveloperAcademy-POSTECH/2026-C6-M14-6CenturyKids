import SwiftUI

/// Figma 2113:6670: 마지막 답변 처리 중. 따봉 영상과 함께 기록이 끝났음을 알린다.
struct SymptomSummaryLoadingView: View {
    /// 글 입력이었으면 같은 자리에 빈 입력 바를 그대로 둔다
    var showsInputBar = true
    var onClose: (() -> Void)?

    var body: some View {
        SymptomChatLayout(title: "알겠어요. 기록해 둘게요.\n말씀하신 내용은 담당 의료진에게 전달됩니다.",
                          sub: "기록이 완료되었습니다.", progress: 1,
                          character: SymptomChatCharacter(current: .thumbsUp, videos: [.thumbsUp]),
                          caption: "잠시만 기다려 주세요...", showsBar: showsInputBar, onClose: onClose) {
            Color.clear.frame(height: 34)
        }
    }
}

#Preview { SymptomSummaryLoadingView(onClose: {}) }
