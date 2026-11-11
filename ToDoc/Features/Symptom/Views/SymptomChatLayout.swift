import SwiftUI

/// Figma '증상 수동 입력 플로우 정리'(2113:5252): 질문 헤더 + 캐릭터 영상 + 아래 채팅 입력 바.
struct SymptomChatLayout<Field: View>: View {
    let title: String
    var sub: String?
    var progress: Double
    var character: SymptomChatCharacter
    var caption: String?
    /// 키보드가 올라와 있으면 안내 문구를 숨기고 바를 키보드 위 8에 둔다
    var isEditing = false
    var showsBar = true
    var canSend = false
    var onClose: (() -> Void)?
    var onSwitchToVoice: (() -> Void)?
    var onSend: (() -> Void)?
    @ViewBuilder let field: () -> Field

    var body: some View {
        VStack(spacing: 0) {
            AppNavigation.QuestionHeader(title, sub: sub, progress: progress, onClose: onClose)
                .padding(.top, 40)
            Spacer(minLength: 16)
            if let caption, !isEditing {
                Text(caption)
                    .appTypography(.label)
                    .foregroundStyle(AppColors.Semantic.Text.action)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }
            if showsBar {
                bar
                    .padding(.horizontal, -11)
                    .padding(.bottom, isEditing ? 8 : 0)
            }
        }
        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                LinearGradient(stops: [
                    .init(color: .white, location: 0.58173),
                    .init(color: Color(red: 239 / 255, green: 251 / 255, blue: 212 / 255), location: 0.71154),
                    .init(color: Color(red: 237 / 255, green: 242 / 255, blue: 235 / 255), location: 0.875)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                // Figma 캐릭터(영상) 칸 가운데(화면 위에서 457)에 맞춘다. 키보드가 올라와도 움직이지 않는다
                character.padding(.top, 196)
            }
            .ignoresSafeArea(.keyboard)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var bar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button { onSwitchToVoice?() } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .frame(width: 34, height: 34)
                    .background(AppColors.Semantic.Background.secondary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(onSwitchToVoice == nil)
            .accessibilityLabel("음성으로 대화하기")
            field()
                .appTypography(.body)
                .foregroundStyle(AppColors.Semantic.Text.default)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            // Figma는 보낼 수 없을 때도 같은 색이라 흐리게 하지 않고 누름만 막는다
            Button { if canSend { onSend?() } } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppColors.Semantic.Text.sub, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("보내기")
            .accessibilityIdentifier("symptom.next")
        }
        .padding(10)
        .background(AppColors.Semantic.Background.default, in: RoundedRectangle(cornerRadius: 30))
    }
}

/// 채팅 화면 캐릭터 영상. 영상들을 겹쳐 두고 지금 것만 보이고 재생한다 (바뀔 때 깜빡임 방지).
struct SymptomChatCharacter: View {
    enum Video: CaseIterable {
        case hello, nodding, thinking, thumbsUp

        var name: String {
            switch self {
            case .hello: "CareCallHello"
            case .nodding: "CareCallNodding"
            case .thinking: "CareCallThinking"
            case .thumbsUp: "CareCallThumbsUp"
            }
        }

        /// 인사 영상만 910×1080으로 잘려 있어 높이를 맞춰 캐릭터 크기를 같게 한다
        var width: CGFloat { self == .hello ? 400 * 910 / 1080 : 252 }
    }

    let current: Video
    var videos: [Video] = [.hello, .nodding, .thinking]

    var body: some View {
        ZStack {
            ForEach(videos, id: \.self) { video in
                CareCallCharacterVideo(name: video.name, isPlaying: video == current)
                    .frame(width: video.width, height: 400)
                    .opacity(video == current ? 1 : 0)
            }
        }
        .frame(height: 400)
    }
}
