import SwiftUI

extension AppFeedback {
    /// Figma Pain Scale(가로 슬라이더). 숫자·한 줄 설명·비탈을 한 묶음으로 그리고 정수 점수만 고릅니다.
    /// 값과 위치는 Figma "통증 점수 슬라이더 — 개발 전달"을 따릅니다 (기준 폭 354).
    struct PainScale: View {
        @Binding var value: Int?
        /// 고를 수 있는 점수. 약 먹기 전은 1...10, 복용 후는 0...10
        var range: ClosedRange<Int> = 1...10
        let label: String
        /// 고르기 전에 보여 주는 한 줄 설명
        var placeholder = ""
        var descriptor: (Int) -> String = { _ in "" }
        var onInteractionEnded: ((Int) -> Void)?

        /// 끄는 동안의 기준 자리. 손을 댄 순간에 정해 두고 움직인 거리만큼 더합니다.
        /// 끌기가 중간에 끊기면 끝났다는 알림이 오지 않으므로, 손을 댄 자리(start)가 달라지면 새로 잡습니다
        @State private var dragAnchor: (start: CGPoint, origin: CGFloat)?

        /// Figma Pain Scale이 변수 없이 직접 지정한 값
        private enum Palette {
            static let unselected = Color(red: 184 / 255, green: 184 / 255, blue: 186 / 255)
            static let handle = Color.white
            static let groove = Color(red: 173 / 255, green: 173 / 255, blue: 178 / 255)
            /// 채워진 자리의 눈금
            static let tick = Color.white
            /// 아직 채워지지 않은 자리의 눈금
            static let emptyTick = Color(red: 191 / 255, green: 191 / 255, blue: 196 / 255)
        }

        /// 비탈 틀 354 × 230 안의 자리. 모양은 y 19~210에 있고 위아래는 손잡이가 튀어나올 자리입니다
        private enum Metrics {
            static let frameHeight: CGFloat = 230
            static let shapeTop: CGFloat = 19
            static let shapeHeight: CGFloat = 191
            static let shapeBottom: CGFloat = 210
            static let handleWidth: CGFloat = 28
            /// 손잡이가 비탈 위아래로 튀어나오는 길이
            static let handleOverhang: CGFloat = 14
            /// 비탈 왼쪽 끝 높이와, 왼쪽에서 오른쪽 끝까지 높아지는 양 (기준 폭에서 경사 0.464)
            static let leadingHeight: CGFloat = 33
            static let rise: CGFloat = 164.26
            static let tickSize: CGFloat = 4
            static let tickBottomGap: CGFloat = 10
            /// 손잡이를 잡았다고 보는 좌우 범위
            static let handleGrabRadius: CGFloat = 22
            static let snap = Animation.spring(response: 0.25, dampingFraction: 0.85)
        }

        var body: some View {
            VStack(spacing: 60) {
                scoreText
                ramp
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value.map { "\($0)점, \(descriptor($0))" } ?? "선택하지 않음")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: select(value.map { $0 + 1 } ?? range.lowerBound)
                // 고르기 전에 내리기만으로 점수가 정해지지 않게 합니다
                case .decrement: if let value { select(value - 1) }
                @unknown default: break
                }
                if let value { onInteractionEnded?(value) }
            }
            // 한 칸 넘을 때마다 선택 진동, 병원 통증 구간(1–3 / 4–6 / 7–10)을 넘을 때는 조금 더 세게
            .sensoryFeedback(trigger: value) { old, new in
                guard let new else { return nil }
                guard let old else { return .selection }
                let low = min(old, new), high = max(old, new)
                return (low <= 3 && high >= 4) || (low <= 6 && high >= 7) ? .impact(weight: .medium) : .selection
            }
        }

        // MARK: 숫자와 한 줄 설명

        private var scoreText: some View {
            VStack(spacing: 4) {
                ZStack {
                    if let value {
                        // 숫자와 "점"은 밑선을 맞추고 4 떨어뜨려 한 묶음으로 가운데에 둡니다
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(value))
                                .appTypography(.display)
                                .foregroundStyle(AppColors.Semantic.Text.default)
                                .contentTransition(.numericText(value: Double(value)))
                            Text("점")
                                .appTypography(.title)
                                .foregroundStyle(AppColors.Semantic.Text.sub)
                        }
                        .fixedSize()
                    } else {
                        Text("–")
                            .appTypography(.display)
                            .foregroundStyle(Palette.unselected)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .animation(.easeOut(duration: 0.3), value: value)

                Text(value.map(descriptor) ?? placeholder)
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
        }

        // MARK: 비탈

        private var ramp: some View {
            GeometryReader { geometry in
                let width = geometry.size.width
                let step = width / 10
                let fillWidth = CGFloat(value ?? 0) * step
                let center = handleCenter(fillWidth: fillWidth, width: width)
                let handleTop = handleTop(center: center, width: width)

                ZStack(alignment: .topLeading) {
                    RampShape()
                        .fill(AppColors.Semantic.Background.secondary)
                        .frame(height: Metrics.shapeHeight)
                        .offset(y: Metrics.shapeTop)
                    filledRamp
                        .frame(height: Metrics.shapeHeight)
                        .mask(alignment: .leading) { Rectangle().frame(width: fillWidth) }
                        .offset(y: Metrics.shapeTop)
                    ForEach(1..<10, id: \.self) { index in
                        Circle()
                            .fill(index <= (value ?? 0) ? Palette.tick : Palette.emptyTick)
                            .frame(width: Metrics.tickSize, height: Metrics.tickSize)
                            .offset(x: CGFloat(index) * step - Metrics.tickSize / 2,
                                    y: Metrics.shapeBottom - Metrics.tickBottomGap - Metrics.tickSize)
                    }
                    handle
                        .frame(width: Metrics.handleWidth,
                               height: Metrics.shapeBottom + Metrics.handleOverhang - handleTop)
                        .offset(x: center - Metrics.handleWidth / 2, y: handleTop)
                }
                .frame(width: width, height: Metrics.frameHeight, alignment: .topLeading)
                .animation(Metrics.snap, value: value)
                .contentShape(Rectangle())
                .gesture(drag(width: width))
            }
            .frame(height: Metrics.frameHeight)
        }

        /// 채움: chart/score 가로 그라데이션 면 + 안쪽 2 두께 테두리 세 겹
        private var filledRamp: some View {
            ZStack {
                RampShape().fill(Self.scoreGradient)
                RampShape().stroke(Self.scoreGradient, lineWidth: 4)
                // 같은 그라데이션을 곱해 테두리를 진하게 만듭니다
                RampShape().stroke(Self.scoreGradient, lineWidth: 4).blendMode(.multiply)
                // 위는 어둡고 아래는 밝게
                RampShape().stroke(Self.borderHighlight, lineWidth: 4)
            }
            // 테두리를 모양 안쪽으로만 남깁니다
            .clipShape(RampShape())
            .compositingGroup()
        }

        private var handle: some View {
            RoundedRectangle(cornerRadius: Metrics.handleWidth / 2)
                .fill(Palette.handle)
                .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(Palette.groove).frame(width: 2, height: 16)
                        }
                    }
                }
        }

        private static let scoreGradient = LinearGradient(stops: [
            .init(color: AppColors.Semantic.Chart.Score.score0, location: 0),
            .init(color: AppColors.Semantic.Chart.Score.score25, location: 0.25),
            .init(color: AppColors.Semantic.Chart.Score.score50, location: 0.5),
            .init(color: AppColors.Semantic.Chart.Score.score75, location: 0.75),
            .init(color: AppColors.Semantic.Chart.Score.score100, location: 1)
        ], startPoint: .leading, endPoint: .trailing)

        private static let borderHighlight = LinearGradient(stops: [
            .init(color: .white.opacity(0), location: 0),
            .init(color: .white.opacity(0), location: 0.45),
            .init(color: .white.opacity(0.63), location: 1)
        ], startPoint: .top, endPoint: .bottom)

        // MARK: 위치 계산

        /// 손잡이 중심 = 채움 폭. 양 끝에서는 손잡이가 비탈 밖으로 나가지 않게 당깁니다 (기준 폭에서 14~340)
        private func handleCenter(fillWidth: CGFloat, width: CGFloat) -> CGFloat {
            min(max(fillWidth, Metrics.handleWidth / 2), width - Metrics.handleWidth / 2)
        }

        /// 손잡이 위 = 손잡이 "오른쪽 끝" x의 비탈 높이에서 14 위. 중심으로 계산하면 모서리 틈으로 채움 색이 비칩니다
        private func handleTop(center: CGFloat, width: CGFloat) -> CGFloat {
            let trailing = center + Metrics.handleWidth / 2
            let rampHeight = Metrics.leadingHeight + Metrics.rise * trailing / max(width, 1)
            return Metrics.shapeBottom - rampHeight - Metrics.handleOverhang
        }

        // MARK: 고르기

        private func drag(width: CGFloat) -> some Gesture {
            let step = width / 10
            return DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let origin: CGFloat
                    if let dragAnchor, dragAnchor.start == gesture.startLocation {
                        origin = dragAnchor.origin
                    } else {
                        // 손잡이를 잡았으면 지금 자리에서, 비탈의 다른 곳을 눌렀으면 그 칸의 점수 자리에서 시작합니다
                        let fillWidth = CGFloat(value ?? 0) * step
                        let center = handleCenter(fillWidth: fillWidth, width: width)
                        let grabsHandle = abs(gesture.startLocation.x - center) <= Metrics.handleGrabRadius
                        origin = grabsHandle ? fillWidth : (gesture.startLocation.x / step).rounded(.up) * step
                        dragAnchor = (gesture.startLocation, origin)
                    }
                    select(Int(((origin + gesture.translation.width) / step).rounded()))
                }
                .onEnded { _ in
                    dragAnchor = nil
                    if let value { onInteractionEnded?(value) }
                }
        }

        private func select(_ score: Int) {
            let clamped = min(max(score, range.lowerBound), range.upperBound)
            if value != clamped { value = clamped }
        }
    }
}

/// Figma "비탈 > 빈 칸 > 모양"의 경로 (354 × 191). 폭이 다르면 가로로만 늘립니다.
private struct RampShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 173.115))
        path.addCurve(to: CGPoint(x: 13.51, y: 151.965),
                      control1: CGPoint(x: 0, y: 163.188), control2: CGPoint(x: 4.503, y: 156.138))
        path.addLine(to: CGPoint(x: 335.86, y: 2.495))
        path.addCurve(to: CGPoint(x: 354, y: 14.075),
                      control1: CGPoint(x: 347.953, y: -3.119), control2: CGPoint(x: 354, y: 0.741))
        path.addLine(to: CGPoint(x: 354, y: 170.975))
        path.addCurve(to: CGPoint(x: 334, y: 190.975),
                      control1: CGPoint(x: 354, y: 184.308), control2: CGPoint(x: 347.333, y: 190.975))
        path.addLine(to: CGPoint(x: 14.89, y: 190.975))
        path.addCurve(to: CGPoint(x: 0, y: 176.085),
                      control1: CGPoint(x: 4.963, y: 190.975), control2: CGPoint(x: 0, y: 186.011))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 354, y: rect.height / 190.975)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
