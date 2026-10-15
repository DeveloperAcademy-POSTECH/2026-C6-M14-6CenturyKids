import SwiftUI

/// Figma 1:1837 / 1:1732 / 수동 입력 3종의 같은 진행·질문·하단 배치.
struct SymptomQuestionLayout<Content: View>: View {
    let question: SymptomConversationQuestion
    var nextTitle = "답변을 입력해 주세요"
    var canProceed = false
    var switchTitle = "음성 전환"
    var showsPrevious = false
    var showsNext = true
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onEnd: (() -> Void)?
    var onSwitch: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    progress
                    VStack(spacing: 8) {
                        if let guidance = question.guidance {
                            Text(guidance).modifier(SymptomTextStyle(size: 16))
                                .foregroundStyle(Color(white: 114 / 255))
                        }
                        Text(question.text)
                            .modifier(SymptomTextStyle(size: 20, weight: .medium))
                            .tracking(-0.2)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityElement(children: .combine)
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 24) {
                HStack {
                    control("종료하기", asset: "CareConversationClose", action: onEnd)
                    Spacer()
                    control(switchTitle, asset: "CareConversationText", action: onSwitch)
                }
                if showsNext {
                    HStack(spacing: 20) {
                        if showsPrevious {
                            Button("이전") { onPrevious?() }
                                .buttonStyle(AppButtonStyle(kind: .back))
                                .disabled(onPrevious == nil)
                        }
                        Button { onNext?() } label: {
                            HStack {
                                Color.clear.frame(width: 12, height: 12)
                                Spacer(minLength: 8)
                                Text(nextTitle)
                                Spacer(minLength: 8)
                                Image("CareConversationNext").frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(AppButtonStyle())
                        .disabled(!canProceed || onNext == nil)
                        .accessibilityIdentifier("symptom.next")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 2)
            .padding(.top, 8)
            .background(.white)
        }
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var progress: some View {
        GeometryReader { geometry in
            let value = question.progress.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } ?? 0
            Capsule().fill(Color(white: 241 / 255))
                .overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [AppColors.primary,
                        Color(red: 214 / 255, green: 242 / 255, blue: 163 / 255), AppColors.primary],
                        startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * value)
                }
                .accessibilityLabel("대화 진행")
                .accessibilityValue(question.progress == nil ? "확인 중" : "\(Int(value * 100))퍼센트")
        }
        .frame(height: 16)
    }

    private func control(_ title: String, asset: String, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: 8) {
                Image(asset).frame(width: 24, height: 24)
                    .frame(width: 60, height: 60)
                    .background(Color(white: 244 / 255), in: Circle())
                    .accessibilityHidden(true)
                Text(title).modifier(SymptomTextStyle(size: 10))
                    .foregroundStyle(Color(white: 101 / 255))
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct SymptomTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight = .regular) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(Font(AppTypography.Style.caption.font(at: size)).weight(weight))
    }
}
