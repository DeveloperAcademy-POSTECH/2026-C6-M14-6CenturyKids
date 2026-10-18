import SwiftUI

/// Figma 원본 게이지에 0...10 정수 입력과 접근성 조절 동작을 연결합니다.
struct PainScoreGauge: View {
    @Binding var value: Int?
    var before: Int?
    let label: String
    var descriptor: (Int) -> String? = painScoreDescription
    @Environment(\.dynamicTypeSize) private var typeSize
    private let trackHeight: CGFloat = 348

    var body: some View {
        VStack(spacing: AppSpacing.columnGap) {
            GeometryReader { geometry in
                let center = geometry.size.width / 2
                ZStack(alignment: .topLeading) {
                    gauge.position(x: center, y: 54 + trackHeight / 2)
                    endpoint(10).position(x: center, y: 15)
                    endpoint(0).position(x: center, y: 437)
                    if value != nil && !typeSize.isAccessibilitySize {
                        comparison
                            .frame(width: 80)
                            .position(x: center + 98.5, y: 229.5)
                    }
                }
            }
            .frame(height: 452)
            if value != nil && typeSize.isAccessibilitySize {
                comparison
            }
        }
    }

    private var gauge: some View {
        let score = min(10, max(0, value ?? 0))
        let position = (CGFloat(10 - score) / 10 * trackHeight).rounded()
        return ZStack(alignment: .top) {
            Image("PainGaugeTrack")
            Image("PainGaugeFill")
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: trackHeight - position)
                }
            // 입력 전의 맨 아래 눈금까지 원본 크기와 위치를 유지합니다.
            Image(value == nil ? "PainGaugeZeroTicks" : "PainGaugeScaleTicks")
                .offset(y: 33.8)
            Capsule().fill(AppColors.surface).frame(width: 48, height: 28)
                .overlay { Capsule().fill(AppColors.Pain.gaugeHandle).frame(width: 20, height: 2) }
                .shadow(color: AppColors.Text.primary.opacity(0.2), radius: 6, y: 3)
                .offset(y: position - 14)
        }
        .frame(width: 94, height: trackHeight)
        .contentShape(Rectangle())
        .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { gesture in
            let fraction = min(1, max(0, gesture.location.y / trackHeight))
            value = Int((10 - fraction * 10).rounded())
        })
        .accessibilityRepresentation {
            Slider(value: Binding(get: { Double(value ?? 0) }, set: { value = Int($0.rounded()) }), in: 0...10, step: 1) {
                Text(label)
            }
            .accessibilityValue("\(value ?? 0)점")
            .accessibilityHint("위아래로 조절하여 0점부터 10점까지 선택해요.")
        }
        .accessibilityIdentifier("pain.score")
    }

    @ViewBuilder private var comparison: some View {
        if let value {
            if let before {
                VStack(spacing: AppSpacing.item) {
                    scoreLabel(before)
                    Image("PainComparisonDown").frame(width: 24, height: 24).accessibilityHidden(true)
                    badge(value)
                    description(value)
                }
            } else {
                scoreLabel(value)
            }
        }
    }

    private func scoreLabel(_ score: Int) -> some View {
        VStack(spacing: AppSpacing.compact) {
            badge(score)
            description(score)
        }
    }

    @ViewBuilder private func description(_ score: Int) -> some View {
        if let text = descriptor(score) {
            Text(text).appFont(.painCaption)
                .foregroundStyle(AppColors.Pain.descriptor).multilineTextAlignment(.center)
        } else {
            Color.clear.frame(height: 17).accessibilityHidden(true)
        }
    }

    private func endpoint(_ score: Int) -> some View {
        Text(String(score))
            .appFont(.painGaugeEndpoint)
            .foregroundStyle(score == 0 ? AppColors.Pain.gaugeHandle : AppColors.surface)
            .frame(width: 30, height: 30)
            .background(score == 0 ? AppColors.Pain.gaugeZero : AppColors.Pain.gaugeMaximum, in: Circle())
            .accessibilityHidden(true)
    }

    private func badge(_ score: Int) -> some View {
        Text(String(score))
            .appFont(.painGaugeBadge)
            .foregroundStyle(AppColors.surface)
            .frame(width: 42, height: 42)
            .background(AppColors.Pain.gaugeScore(score), in: Circle())
            .accessibilityLabel("\(score)점")
    }
}
