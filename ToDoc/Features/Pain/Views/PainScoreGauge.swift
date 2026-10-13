import SwiftUI

/// 원본 게이지 에셋 위에서 정수 점수만 선택합니다. 분류 구간을 추정하지 않습니다.
struct PainScoreGauge: View {
    @Binding var value: Int?
    var before: Int?
    let label: String
    var descriptor: (Int) -> String? = { _ in nil }
    @Environment(\.dynamicTypeSize) private var typeSize
    private let height: CGFloat = 347.622

    var body: some View {
        VStack(spacing: 16) {
        GeometryReader { geometry in
            let x = geometry.size.width / 2 - 9
            ZStack(alignment: .topLeading) {
                gauge.position(x: x, y: 45 + height / 2)
                badge(10, size: 30).position(x: x, y: 15)
                badge(1, size: 30).position(x: x, y: 423)
                if let value {
                    Group {
                        if let before {
                            VStack(spacing: 0) {
                                scoreLabel(before).padding(.bottom, 15)
                                Image("PainComparisonDown").frame(width: 24, height: 24)
                                    .accessibilityHidden(true).padding(.bottom, 20)
                                scoreLabel(value)
                            }
                        } else { scoreLabel(value) }
                    }
                    .frame(width: 96)
                    .position(x: min(geometry.size.width - 48, x + 109), y: before == nil ? 217 : 214.5)
                }
                // 0점 선택은 Domain에 있으나 하이파이 원본에는 없어 기본 버튼으로 제공합니다.
                if !typeSize.isAccessibilitySize {
                    zeroButton.position(x: 62, y: 423)
                }
            }
        }
        .frame(height: 438)
        if typeSize.isAccessibilitySize { zeroButton }
        }
    }

    private var zeroButton: some View {
        Button("통증 없음 (0점)") { value = 0 }.font(.caption).buttonStyle(.bordered)
    }

    private var gauge: some View {
        let position = CGFloat(10 - min(10, max(1, value ?? 10))) / 9 * height
        return ZStack(alignment: .top) {
            Image("PainGauge").resizable()
            if value != nil {
                Image("PainGauge").resizable().renderingMode(.template)
                    .foregroundStyle(Color(white: 217 / 255))
                    .mask(alignment: .top) { Rectangle().frame(height: position) }
            }
            Image("PainGaugeTicks").frame(width: 52, height: 290).offset(y: 29)
            Capsule().fill(.white).frame(width: 48, height: 28)
                .overlay { Capsule().fill(Color(white: 176 / 255)).frame(width: 20, height: 2) }
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .offset(y: position - 14)
        }
        .frame(width: 94.135, height: height)
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { gesture in
            let fraction = min(1, max(0, gesture.location.y / height))
            value = Int((10 - fraction * 9).rounded())
        })
        .accessibilityRepresentation {
            Slider(value: Binding(get: { Double(value ?? 0) }, set: { value = Int($0.rounded()) }), in: 0...10, step: 1) {
                Text(label)
            }
            .accessibilityValue(value.map { "\($0)점" } ?? "선택하지 않음")
        }
    }

    private func scoreLabel(_ score: Int) -> some View {
        VStack(spacing: 3) {
            badge(score, size: 42)
            if let text = descriptor(score) { Text(text).appTextStyle(.label) }
            else { Color.clear.frame(height: 21).accessibilityHidden(true) }
        }
    }

    private func badge(_ score: Int, size: CGFloat) -> some View {
        Text(String(score))
            .font(Font(AppTypography.Style.label.font(at: size == 30 ? 16 : 22.4)))
            .foregroundStyle(score <= 1 ? Color.black : .white)
            .frame(width: size, height: size)
            .background(color(score), in: Circle())
    }

    private func color(_ score: Int) -> Color {
        // 원본 게이지 색상에 따른 표시이며 의료 분류 기준이 아닙니다.
        let stops: [(Int, (Double, Double, Double))] = [
            (1, (197, 242, 118)), (3, (253, 208, 72)), (7, (254, 150, 70)), (10, (255, 73, 70))
        ]
        let score = min(10, max(1, score))
        let upper = stops.firstIndex { $0.0 >= score } ?? 3
        let lower = max(0, upper - 1)
        let start = stops[lower], end = stops[upper]
        let ratio = end.0 == start.0 ? 0 : Double(score - start.0) / Double(end.0 - start.0)
        func component(_ from: Double, _ to: Double) -> Double { (from + (to - from) * ratio) / 255 }
        return Color(red: component(start.1.0, end.1.0), green: component(start.1.1, end.1.1),
                     blue: component(start.1.2, end.1.2))
    }
}
