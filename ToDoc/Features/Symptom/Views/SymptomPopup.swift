import SwiftUI

/// Figma 증상 대화하기 팝업 (기록 중단·응급·마이크 비활성화·서비스 오류). 화면을 60% 검게 덮고 가운데 300pt 카드를 띄웁니다.
struct SymptomPopup: View {
    private let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .accessibilityHidden(true)
            content
                .frame(width: 300)
                .background(SymptomPopupStyle.background, in: RoundedRectangle(cornerRadius: 40))
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                // Figma: 카드 가운데가 화면 가운데보다 조금 위
                .offset(y: -40)
        }
    }
}

private enum SymptomPopupStyle {
    static let background = Color(white: 248 / 255)
    static let message = Color(white: 114 / 255)
}

extension SymptomPopup {
    /// Figma 316:6970 입력 중단: 진행률과 함께 그만두면 기록이 초기화된다고 알린다
    static func end(progress: Double?, onContinue: @escaping () -> Void, onQuit: @escaping () -> Void) -> SymptomPopup {
        let percent = Int((min(1, max(0, progress ?? 0)) * 100).rounded())
        let rate = Text("\(percent)%").foregroundStyle(Color(red: 106 / 255, green: 166 / 255, blue: 0))
        return SymptomPopup {
            VStack(spacing: 40) {
                VStack(spacing: 24) {
                    Text("기록을 중단하시나요?").modifier(SymptomTextStyle(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(rate)를 진행했어요.\n지금까지의 기록한 내용이 초기화됩니다.")
                        .modifier(SymptomTextStyle(size: 14, weight: .medium)).foregroundStyle(SymptomPopupStyle.message)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 24) {
                    Button(action: onContinue) {
                        Text("계속 작성하기").modifier(SymptomTextStyle(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 41 / 255, green: 64 / 255, blue: 0))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(AppColors.primary, in: RoundedRectangle(cornerRadius: 24))
                            .contentShape(RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    Button(action: onQuit) {
                        Text("그만하기").modifier(SymptomTextStyle(size: 16)).foregroundStyle(Color(white: 123 / 255))
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }
}

#Preview("기록 중단") { SymptomPopup.end(progress: 0.63, onContinue: {}, onQuit: {}) }
