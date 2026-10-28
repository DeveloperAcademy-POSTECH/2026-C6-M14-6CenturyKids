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

    /// Figma 547:23175 응급상황 (Dialog: 메인 버튼 + 글자 버튼)
    static func emergency(onStop: @escaping () -> Void, onContinue: @escaping () -> Void) -> SymptomPopup {
        SymptomPopup {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("응급상황으로 판단되었습니다").modifier(SymptomTextStyle(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 43 / 255, green: 40 / 255, blue: 43 / 255))
                        .accessibilityAddTraits(.isHeader)
                    Text("기록을 잠시 멈추고 의료진과 연락해 보세요").modifier(SymptomTextStyle(size: 14))
                        .foregroundStyle(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255))
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 24)
                VStack(spacing: 4) {
                    Button(action: onStop) { AppForwardLabel(title: "기록 중단", asset: "CareConversationNext") }
                        .buttonStyle(AppButtonStyle())
                    Button(action: onContinue) {
                        Text("기록 이어가기").modifier(SymptomTextStyle(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 71 / 255, green: 109 / 255, blue: 23 / 255))
                            .padding(.horizontal, 16).frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }

    /// Figma 316:6916 마이크 비활성화 안내 (케어콜 마이크 거부)
    static func microphone(onConfirm: @escaping () -> Void, onSettings: @escaping () -> Void) -> SymptomPopup {
        alert(title: "오디오 녹음이 비활성화됨",
              message: "ToDoc에서 마이크에 접근하는 것을 허용하지 않았기 때문에 현재 마이크 또는 다른 소스로 오디오 녹음을 할 수 없습니다. "
                + "오디오를 녹음하려면 설정 앱을 열고 ToDoc을 탭한 다음 마이크를 탭하십시오",
              showsWarning: false, onConfirm: onConfirm, onSettings: onSettings)
    }

    /// Figma 316:6941 준비 실패·미연결
    static func service(onConfirm: @escaping () -> Void, onSettings: @escaping () -> Void) -> SymptomPopup {
        alert(title: "서비스 이용이 원활하지 않아요", message: "불편을 드려 죄송합니다.\n잠시 후에 다시 시도해 주세요",
              showsWarning: true, onConfirm: onConfirm, onSettings: onSettings)
    }

    /// 글자 버튼 두 개(확인·설정)인 알림
    private static func alert(title: String, message: String, showsWarning: Bool,
                              onConfirm: @escaping () -> Void, onSettings: @escaping () -> Void) -> SymptomPopup {
        SymptomPopup {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    if showsWarning {
                        AppFeedback.StatusIcon(kind: .error, size: 72)
                    }
                    Text(title).modifier(SymptomTextStyle(size: 16, weight: .semibold)).foregroundStyle(.black)
                        .accessibilityAddTraits(.isHeader)
                    Text(message).modifier(SymptomTextStyle(size: 14, weight: .medium)).foregroundStyle(SymptomPopupStyle.message)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 23)
                .padding(.top, showsWarning ? 25 : 43)
                .padding(.bottom, 24)
                Divider()
                HStack(spacing: 0) {
                    pairButton("확인", action: onConfirm)
                    Divider()
                    pairButton("설정", action: onSettings)
                }
                .frame(height: 60)
            }
        }
    }

    private static func pairButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).modifier(SymptomTextStyle(size: 16, weight: .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("기록 중단") { SymptomPopup.end(progress: 0.63, onContinue: {}, onQuit: {}) }
#Preview("응급") { SymptomPopup.emergency(onStop: {}, onContinue: {}) }
#Preview("마이크") { SymptomPopup.microphone(onConfirm: {}, onSettings: {}) }
#Preview("서비스") { SymptomPopup.service(onConfirm: {}, onSettings: {}) }
