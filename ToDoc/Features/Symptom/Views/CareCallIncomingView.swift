import SwiftUI

/// Figma 1:1658의 수신 화면. 준비/권한 정책은 상위 ViewModel에서 결정합니다.
struct CareCallIncomingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var canAnswer = false
    var onAnswer: (() -> Void)?
    var onEnd: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onSwitchToText: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 402
            ZStack(alignment: .top) {
                backdrop(scale: scale)
                backdrop(scale: scale)
                    .compositingGroup()
                    .blur(radius: 25 * scale)
                    .mask(alignment: .top) {
                        LinearGradient(colors: [.clear, AppColors.Text.primary, AppColors.Text.primary], startPoint: .top, endPoint: .bottom)
                            .frame(height: 80 * scale)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(alignment: .bottom) { Rectangle().padding(.top, 80 * scale) }
                            .padding(.top, 520 * scale)
                    }
                menuGradient
                    .frame(height: max(0, geometry.size.height - 520 * scale))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Image("CareCallBackdropImage")
                    .resizable()
                    .frame(width: 947 * scale, height: 812 * scale)
                    .position(x: (-826 + 947 / 2) * scale, y: (48 + 812 / 2) * scale)
                    .accessibilityHidden(true)
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: AppSpacing.question) {
                            callTitle
                            Spacer(minLength: 80 * scale)
                            controls
                        }
                        .padding(.horizontal, 24 * scale)
                        .padding(.top, 102 * scale)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 55 * scale))
                        .frame(minHeight: geometry.size.height)
                    }
                } else {
                    callTitle
                        .frame(maxWidth: .infinity)
                        .padding(.top, 102 * scale)
                    controls
                        .padding(.horizontal, 24 * scale)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 55 * scale))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var callTitle: some View {
        VStack(spacing: AppSpacing.content) {
            Text("영상통화")
                .appFont(.incomingSubtitle)
                .foregroundStyle(AppColors.CareCall.incomingSubtitle)
            Text("Dr. 학로")
                .appFont(.incomingTitle)
                .tracking(-0.4)
                .foregroundStyle(AppColors.surface)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func backdrop(scale: CGFloat) -> some View {
        background.overlay(alignment: .top) {
            Image("CareCallHakro")
                .resizable()
                .frame(width: 687 * scale, height: 687 * scale)
                .offset(y: 212 * scale)
                .accessibilityHidden(true)
        }
    }

    private var background: some View {
        AppColors.CareCall.incomingBackground.overlay(AppColors.CareCall.incomingShade)
    }

    private var menuGradient: some View { AppColors.CareCall.incomingMenu }

    private var controls: some View {
        VStack(spacing: AppSpacing.question) {
            HStack(alignment: .top, spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 120) {
                control("10분 미루기", asset: "CareCallAlarm", iconSize: 20, action: onPostpone)
                control("채팅으로 전환", asset: "CareCallChat", iconSize: 24, action: onSwitchToText)
            }
            HStack(alignment: .top, spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 120) {
                control("종료", asset: "CareCallClose", circle: AppColors.CareCall.incomingEnd, action: onEnd)
                control("전화받기", asset: "CareCallPhone", circle: AppColors.CareCall.incomingAnswer,
                        action: canAnswer ? onAnswer : nil)
                    .accessibilityIdentifier("carecall.start")
            }
        }
        .buttonStyle(AppPressStyle())
    }

    private func control(_ title: String, asset: String, iconSize: CGFloat = 24,
                         circle: Color? = nil, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: AppSpacing.compact) {
                Image(asset)
                    .frame(width: iconSize, height: iconSize)
                    .frame(width: circle == nil ? nil : 74, height: circle == nil ? 24 : 74)
                    .background(circle ?? .clear, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .appFont(.incomingControl)
                    .foregroundStyle(AppColors.CareCall.incomingControlText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 74, minHeight: 46)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
    }
}

#Preview("Figma 수신 화면") {
    CareCallIncomingView(canAnswer: true, onAnswer: {}, onEnd: {}, onPostpone: {}, onSwitchToText: {})
}
