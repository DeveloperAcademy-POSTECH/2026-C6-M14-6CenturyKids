import SwiftUI

/// Figma 1:1658의 수신 화면. 준비/권한 정책은 상위 ViewModel에서 결정합니다.
struct CareCallIncomingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var subtitleSize = 16.0
    @ScaledMetric(relativeTo: .title) private var titleSize = 40.0
    @ScaledMetric(relativeTo: .caption) private var controlLabelSize = 12.0
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
                        LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom)
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
                        VStack(spacing: 40) {
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
        VStack(spacing: 16) {
            Text("영상통화")
                .font(Font(AppTypography.Style.caption.font(at: subtitleSize)))
                .foregroundStyle(Color(white: 216 / 255))
            Text("Dr. 학로")
                .font(Font(AppTypography.Style.heading.font(at: titleSize)))
                .tracking(-0.4)
                .foregroundStyle(.white)
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
        LinearGradient(stops: [
            .init(color: Color(red: 230 / 255, green: 236 / 255, blue: 244 / 255), location: 0.10509),
            .init(color: Color(red: 194 / 255, green: 238 / 255, blue: 130 / 255), location: 2.4669)
        ], startPoint: .top, endPoint: .bottom)
        .overlay {
            LinearGradient(stops: [
                .init(color: rgb(110, 116, 124).opacity(0.82), location: 0),
                .init(color: rgb(123, 133, 121).opacity(0.82), location: 0.62019),
                .init(color: rgb(107, 116, 106).opacity(0.82), location: 0.79327),
                .init(color: rgb(82, 90, 78).opacity(0.82), location: 0.913462),
                .init(color: rgb(36, 39, 33).opacity(0.82), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    private var menuGradient: some View {
        LinearGradient(stops: [
            .init(color: rgb(94, 104, 92).opacity(0), location: 0),
            .init(color: rgb(93, 101, 92).opacity(0.18), location: 0.086538),
            .init(color: rgb(83, 91, 80).opacity(0.47), location: 0.20673),
            .init(color: rgb(80, 87, 77).opacity(0.67), location: 0.29327),
            .init(color: rgb(79, 85, 76).opacity(0.77), location: 0.37981),
            .init(color: rgb(81, 87, 78).opacity(0.698), location: 0.47115),
            .init(color: rgb(99, 105, 94).opacity(0), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    private var controls: some View {
        VStack(spacing: 40) {
            HStack(alignment: .top, spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 120) {
                control("10분 미루기", asset: "CareCallAlarm", iconSize: 20, action: onPostpone)
                control("채팅으로 전환", asset: "CareCallChat", iconSize: 24, action: onSwitchToText)
            }
            HStack(alignment: .top, spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 120) {
                control("종료", asset: "CareCallClose", circle: rgb(234, 77, 62), action: onEnd)
                control("전화받기", asset: "CareCallPhone", circle: rgb(118, 213, 113),
                        action: canAnswer ? onAnswer : nil)
                    .accessibilityIdentifier("carecall.start")
            }
        }
        .buttonStyle(CareCallControlStyle())
    }

    private func control(_ title: String, asset: String, iconSize: CGFloat = 24,
                         circle: Color? = nil, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            VStack(spacing: 8) {
                Image(asset)
                    .frame(width: iconSize, height: iconSize)
                    .frame(width: circle == nil ? nil : 74, height: circle == nil ? 24 : 74)
                    .background(circle ?? .clear, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(Font(AppTypography.Style.caption.font(at: controlLabelSize)))
                    .foregroundStyle(Color(white: 231 / 255))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 74, minHeight: 46)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
    }

    private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

private struct CareCallControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
    }
}

#Preview("Figma 수신 화면") {
    CareCallIncomingView(canAnswer: true, onAnswer: {}, onEnd: {}, onPostpone: {}, onSwitchToText: {})
}
