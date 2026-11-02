import SwiftUI

/// 원본 게이지 에셋 위에서 정수 점수만 선택합니다. 분류 구간을 추정하지 않습니다.
struct PainScoreGauge: View {
    @Binding var value: Int?
    /// 고르기 전(value가 nil)에 보여 줄 자리. 선택한 값으로 치지 않습니다
    var initialValue: Int?
    var before: Int?
    let label: String
    var descriptor: (Int) -> String? = { _ in nil }
    private let height: CGFloat = 347.622

    private var shown: Int? { value ?? initialValue }

    var body: some View {
        GeometryReader { geometry in
            let x = geometry.size.width / 2
            ZStack(alignment: .topLeading) {
                gauge.position(x: x, y: 54 + height / 2)
                badge(10, size: 30).position(x: x, y: 15).accessibilityHidden(true)
                badge(0, size: 30).position(x: x, y: 437).accessibilityHidden(true)
                if let shown {
                    // Figma Pain Scale: 통증 말은 게이지 왼쪽(13 떨어짐)에서 손잡이와 같은 높이로 움직입니다
                    if let text = descriptor(shown) {
                        Text(text).appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.placeholder)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: max(0, x - 47 - 13), alignment: .trailing)
                            .position(x: (x - 47 - 13) / 2, y: 54 + handleOffset(shown))
                            .accessibilityHidden(true)
                    }
                    // 먹기 전 점수(회색)는 위에 고정하고, 지금 점수는 손잡이와 상관없이 같은 자리에 둡니다 (Figma 9 · 이전 회색 · 위 고정)
                    if let before {
                        scoreCircle(before, previous: true).position(x: x + 98.5, y: 229 - 67)
                        Image("PainPreviousArrow").position(x: x + 98.5, y: 229 - 35).accessibilityHidden(true)
                    }
                    scoreCircle(shown).position(x: x + 98.5, y: 229)
                }
            }
        }
        .frame(height: 452)
    }

    private func handleOffset(_ score: Int) -> CGFloat {
        CGFloat(10 - min(10, max(0, score))) / 10 * height
    }

    private var gauge: some View {
        let position = handleOffset(shown ?? 10)
        return ZStack(alignment: .top) {
            Image("PainGauge").resizable()
            if shown != nil {
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
            value = Int((10 - fraction * 10).rounded())
        })
        .accessibilityRepresentation {
            Slider(value: Binding(get: { Double(shown ?? 0) }, set: { value = Int($0.rounded()) }), in: 0...10, step: 1) {
                Text(label)
            }
            .accessibilityValue(value.map { "\($0)점" } ?? "선택하지 않음")
        }
    }

    /// Figma 점수 원(42): 지금 점수는 점수 색, 먹기 전 점수는 회색
    private func scoreCircle(_ score: Int, previous: Bool = false) -> some View {
        Text(String(score))
            .appTypography(.title)
            .foregroundStyle(previous ? AppColors.Semantic.Text.sub : textColor(score))
            .frame(width: 42, height: 42)
            .background(previous ? AppColors.Semantic.Background.secondary : color(score), in: Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(previous ? "먹기 전 \(score)점" : "\(score)점, \(descriptor(score) ?? "")")
    }

    private func badge(_ score: Int, size: CGFloat) -> some View {
        Text(String(score))
            .font(Font(AppTypography.Style.label.font(at: size == 30 ? 16 : 22.4)))
            .foregroundStyle(score == 0 ? Color(white: 176 / 255) : .white)
            .frame(width: size, height: size)
            .background(score == 0 ? Color(white: 217 / 255) : color(score), in: Circle())
    }

    private func color(_ score: Int) -> Color {
        // 원본 게이지 색상에 따른 표시이며 의료 분류 기준이 아닙니다. 0점은 1점과 같은 연두입니다 (Figma 9 · 지금 0점).
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

    /// Figma 점수 원 글자: 0점 brand/800, 5점 red/800, 10점 red/950.
    // ponytail: 시안에 있는 0·5·10점 사이는 가까운 색으로 나눴습니다. 점수별 글자색이 정해지면 바꿉니다.
    private func textColor(_ score: Int) -> Color {
        switch score {
        case ...2: Color(red: 60 / 255, green: 88 / 255, blue: 26 / 255)
        case 3...8: Color(red: 139 / 255, green: 35 / 255, blue: 31 / 255)
        default: Color(red: 73 / 255, green: 21 / 255, blue: 18 / 255)
        }
    }
}
