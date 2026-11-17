import SwiftUI

struct CareCallIncomingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRinging = false
    var canAnswer = false
    var onAnswer: (() -> Void)?
    var onEnd: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    private var usesScrollableLayout: Bool { dynamicTypeSize >= .xxxLarge }

    var body: some View {
        Group {
            if usesScrollableLayout {
                ScrollView {
                    VStack(spacing: 24) {
                        callTitle
                            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                        character
                            .aspectRatio(910.0 / 1080, contentMode: .fit)
                            .frame(maxWidth: 300)
                            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                        alternateControls
                    }
                    .padding(.vertical, 24)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    callControls
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                        .background(.white)
                }
            } else {
                VStack(spacing: 0) {
                    callTitle.padding(.top, 40)
                    Spacer()
                    controls.padding(.bottom, 8)
                }
            }
        }
        .buttonStyle(AppActions.PressStyle())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { backdrop.accessibilityHidden(true).ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if !reduceMotion { isRinging = true } }
    }

    private var character: some View {
        CareCallCharacterVideo(name: "CareCallHello", isPlaying: canAnswer)
    }

    private var backdropGradient: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 239 / 255, green: 251 / 255, blue: 212 / 255), location: 0),
            .init(color: .white, location: 0.7)
        ], startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder
    private var backdrop: some View {
        if usesScrollableLayout {
            backdropGradient
        } else {
            backdropGradient
                .overlay(alignment: .top) {
                    Image("CareCallGlow").padding(.top, 200)
                }
                .overlay(alignment: .top) {
                    character
                        .frame(width: 382, height: 453)
                        .padding(.top, 247)
                }
                .overlay(alignment: .bottom) {
                    let fade = LinearGradient(stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.95), location: 0.45),
                        .init(color: .white, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(.ultraThinMaterial)
                        .mask(fade)
                        .overlay(fade)
                        .frame(height: 330)
                }
                .clipped()
        }
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
            alternateControls
            callControls
        }
    }

    private var alternateControls: some View {
        HStack(alignment: .top, spacing: usesScrollableLayout ? 16 : nil) {
            control("10분 뒤에", asset: "CareCallAlarm", iconSize: 20, diameter: 56, labelSize: 13,
                    fill: AppColors.Semantic.Background.secondary, labelColor: AppColors.Semantic.Text.sub,
                    action: onPostpone)
            if !usesScrollableLayout { Spacer(minLength: 16) }
            control("글로 답할게요", asset: "CareCallChat", iconSize: 24, diameter: 56, labelSize: 13,
                    fill: AppColors.Semantic.Background.secondary, labelColor: AppColors.Semantic.Text.sub,
                    action: onSwitchToText)
        }
        .padding(.horizontal, usesScrollableLayout ? AppLayout.Phone.horizontalMargin : 55)
    }

    private var callControls: some View {
        HStack(alignment: .top, spacing: usesScrollableLayout ? 16 : nil) {
            control("거절", asset: "CareCallClose", iconSize: 24, diameter: 76,
                    fill: AppColors.Semantic.Border.error, labelColor: AppColors.Semantic.Text.default,
                    action: onEnd)
            if !usesScrollableLayout { Spacer(minLength: 16) }
            control("받기", asset: "CareCallPhone", iconSize: 24, diameter: 76,
                    fill: AppColors.Semantic.Primary.default, labelColor: AppColors.Semantic.Text.default,
                    action: canAnswer ? onAnswer : nil)
                .background(alignment: .top) {
                    Image("CareCallRing")
                        .animation(.easeInOut(duration: 1.2).repeatForever()) { ring in
                            ring.scaleEffect(isRinging ? 1 : 0.8)
                        }
                        .opacity(canAnswer ? 1 : 0)
                        .padding(.top, -24)
                        .accessibilityHidden(true)
                }
                .accessibilityIdentifier("carecall.start")
        }
        .padding(.horizontal, usesScrollableLayout ? AppLayout.Phone.horizontalMargin : 55)
    }

    private func control(_ title: String, asset: String, iconSize: CGFloat, diameter: CGFloat, labelSize: CGFloat = 14,
                         fill: Color, labelColor: Color, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: 8) {
                Image(asset)
                    .frame(width: iconSize, height: iconSize)
                    .frame(width: diameter, height: diameter)
                    .background(fill, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .modifier(SymptomTextStyle(size: labelSize, weight: .medium))
                    .frame(minHeight: 20)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: usesScrollableLayout ? nil : 96)
            .frame(maxWidth: usesScrollableLayout ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
    }
}

#Preview("수신 화면") {
    CareCallIncomingView(canAnswer: true, onAnswer: {}, onEnd: {}, onPostpone: {}, onSwitchToText: {})
}
