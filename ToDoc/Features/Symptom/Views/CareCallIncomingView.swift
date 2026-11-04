import SwiftUI

/// Figma 1766:28104의 수신 화면. 준비/권한 정책은 상위 ViewModel에서 결정합니다.
/// 가운데 캐릭터 영상 자리는 아직 비워 둡니다.
struct CareCallIncomingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRinging = false
    var canAnswer = false
    var onAnswer: (() -> Void)?
    var onEnd: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 40) {
                        callTitle
                        controls
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 8)
                }
            } else {
                VStack(spacing: 0) {
                    callTitle.padding(.top, 40)
                    Spacer()
                    controls.padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if !reduceMotion { isRinging = true } }
    }

    /// 배경 · 캐릭터 뒤 빛 · (영상 자리) · 아래 흰 덮개. 화면 크기에 영향을 주지 않게 배경으로 그린다
    private var backdrop: some View {
        LinearGradient(stops: [
            .init(color: Color(red: 239 / 255, green: 251 / 255, blue: 212 / 255), location: 0),
            .init(color: .white, location: 0.7)
        ], startPoint: .top, endPoint: .bottom)
        .overlay(alignment: .top) {
            Image("CareCallGlow").padding(.top, 200)
        }
        .overlay(alignment: .bottom) {
            // 아래 버튼이 영상 위에서도 읽히게 흰색으로 덮는다
            LinearGradient(stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(0.95), location: 0.45),
                .init(color: .white, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: 330)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var callTitle: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image("CareCallDot")
                    .opacity(isRinging ? 0.2 : 1)
                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: isRinging)
                    .accessibilityHidden(true)
                Text("영상통화")
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }
            Text("Dr. 학로")
                .appTypography(.headline)
                .foregroundStyle(AppColors.Semantic.Text.default)
            Text("오늘 몸 상태를 여쭤볼게요")
                .appTypography(.labelLarge)
                .foregroundStyle(AppColors.Semantic.Text.sub)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                control("10분 뒤에", asset: "CareCallAlarm", iconSize: 20, diameter: 56,
                        fill: AppColors.Semantic.Background.secondary, labelColor: AppColors.Semantic.Text.sub,
                        action: onPostpone)
                Spacer(minLength: 16)
                control("글로 답할게요", asset: "CareCallChat", iconSize: 24, diameter: 56,
                        fill: AppColors.Semantic.Background.secondary, labelColor: AppColors.Semantic.Text.sub,
                        action: onSwitchToText)
            }
            HStack(alignment: .top) {
                control("거절", asset: "CareCallClose", iconSize: 24, diameter: 76,
                        fill: AppColors.Semantic.Border.error, labelColor: AppColors.Semantic.Text.default,
                        action: onEnd)
                Spacer(minLength: 16)
                control("받기", asset: "CareCallPhone", iconSize: 24, diameter: 76,
                        fill: AppColors.Semantic.Primary.default, labelColor: AppColors.Semantic.Text.default,
                        action: canAnswer ? onAnswer : nil)
                    .background(alignment: .top) {
                        // 받을 수 있을 때만 받기 둘레 빛이 퍼진다
                        Image("CareCallRing")
                            .scaleEffect(isRinging ? 1 : 0.8)
                            .opacity(canAnswer ? 1 : 0)
                            .animation(.easeInOut(duration: 1.2).repeatForever(), value: isRinging)
                            .padding(.top, -24)
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("carecall.start")
            }
        }
        .padding(.horizontal, 55)
        .buttonStyle(AppActions.PressStyle())
    }

    private func control(_ title: String, asset: String, iconSize: CGFloat, diameter: CGFloat,
                         fill: Color, labelColor: Color, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: 8) {
                Image(asset)
                    .frame(width: iconSize, height: iconSize)
                    .frame(width: diameter, height: diameter)
                    .background(fill, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .appTypography(.label)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 96)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
    }
}

#Preview("Figma 수신 화면") {
    CareCallIncomingView(canAnswer: true, onAnswer: {}, onEnd: {}, onPostpone: {}, onSwitchToText: {})
}
