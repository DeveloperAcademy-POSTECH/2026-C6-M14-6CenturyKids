import SwiftUI

/// Figma 1:1823. 저장 성공 이후 부모 흐름에서 표시합니다.
struct SymptomCompletionView: View {
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 40) {
                        AppFeedback.StatusIcon(kind: .success, size: 100)
                        VStack(spacing: 24) {
                            Text("말씀해 주신 내용을 바탕으로\n문진 기록을 정리했어요.")
                                .modifier(SymptomTextStyle(size: 20, weight: .medium))
                            Text("잠시만 기다려 주세요")
                                .modifier(SymptomTextStyle(size: 16))
                                .foregroundStyle(Color(white: 114 / 255))
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, max(24, (geometry.size.height - 180) * 0.35))
                    .padding(.bottom, 24)
                }
                VStack(spacing: 20) {
                    Button { onShowRecord?() } label: {
                        HStack {
                            Color.clear.frame(width: 12, height: 12)
                            Spacer(minLength: 8)
                            Text("기록 확인하기")
                            Spacer(minLength: 8)
                            Image("CareConversationNext").frame(width: 12, height: 12)
                        }
                    }
                    .buttonStyle(AppButtonStyle()).disabled(onShowRecord == nil)
                    Button("홈으로 가기") { onHome?() }
                        .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onHome == nil)
                }
                .padding(.horizontal, 24).padding(.bottom, 2)
            }
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview { SymptomCompletionView(onShowRecord: {}, onHome: {}) }
