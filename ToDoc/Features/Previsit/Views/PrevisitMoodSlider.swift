import SwiftUI

struct PrevisitMoodSlider: View {
    let selection: StateOfMind?
    let onSelect: (StateOfMind) -> Void

    @GestureState private var dragging: StateOfMind? = nil
    @Environment(\.layoutDirection) private var layoutDirection
    @ScaledMetric(relativeTo: .body) private var labelLineHeight: CGFloat = 24

    private struct Stop {
        let state: StateOfMind
        let label: String
        let dialogue: String
        let artwork: String
        let color: Color
        let thumbPosition: CGFloat
        let fillWidth: CGFloat
    }

    // The positions are relative to the usable track in the 354pt Figma control.
    private static let stops: [Stop] = [
        Stop(state: .unsure, label: "몰라", dialogue: "잘 모르겠어", artwork: "Unsure",
             color: AppColors.Semantic.Avatar.unsure, thumbPosition: 0, fillWidth: 0),
        Stop(state: .candid, label: "안정", dialogue: "편하게 이야기 해 드릴게요", artwork: "Calm",
             color: AppColors.Semantic.Avatar.calm, thumbPosition: 66.0 / 306.0, fillWidth: 95.0 / 354.0),
        Stop(state: .comfortable, label: "긴장", dialogue: "차분히 이야기 해 드릴게요", artwork: "Tense",
             color: AppColors.Semantic.Avatar.worried, thumbPosition: 0.5, fillWidth: 181.0 / 354.0),
        Stop(state: .slowly, label: "걱정", dialogue: "천천히 이야기 해 드릴게요", artwork: "Worried",
             color: AppColors.Semantic.Avatar.anxious, thumbPosition: 231.0 / 306.0, fillWidth: 260.0 / 354.0),
        Stop(state: .carefully, label: "불안", dialogue: "조심스럽게 이야기 해 드릴게요", artwork: "Anxious",
             color: AppColors.Semantic.Avatar.notReady, thumbPosition: 1, fillWidth: 1)
    ]

    private var current: Stop {
        Self.stops.first { $0.state == (dragging ?? selection ?? .unsure) } ?? Self.stops[0]
    }

    private var isAwaitingSelection: Bool { selection == nil && dragging == nil }

    var body: some View {
        VStack(spacing: 0) {
            speechBubble.padding(.bottom, 2)
            illustration
            slider.padding(.top, 10)
            HStack {
                Text("평온")
                Spacer()
                Text("불안")
            }
            .appTypography(.label)
            .foregroundStyle(Color(white: 132.0 / 255.0))
            .padding(.top, 2)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: 354)
        .frame(maxWidth: .infinity)
    }

    private var speechBubble: some View {
        VStack(spacing: -4) {
            Text(isAwaitingSelection ? "슬라이더로 상태를 골라주세요" : current.dialogue)
                .appTypography(.label)
                .foregroundStyle(AppColors.Semantic.Text.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(20)
                .background {
                    Capsule().fill(
                        LinearGradient(colors: [Color(white: 232.0 / 255.0), Color(white: 218.0 / 255.0)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                }
            Image("PrevisitMoodSpeechTail")
                .resizable()
                .frame(width: 14, height: 11.1244)
                .rotationEffect(.degrees(180))
                .accessibilityHidden(true)
        }
        .offset(x: 4)
    }

    private var illustration: some View {
        Color.clear
            .aspectRatio(354.0 / 320.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let scale = geometry.size.width / 354
                    let center = geometry.size.width / 2

                    Image("PrevisitMoodGlow\(current.artwork)")
                        .resizable()
                        .frame(width: 402 * scale, height: 402 * scale)
                        .position(x: center - scale, y: 165 * scale)

                    ZStack {
                        Image(current.state == .carefully ? "PrevisitMoodWorried" : "PrevisitMood\(current.artwork)")
                            .resizable()
                        if current.state == .carefully {
                            Image("PrevisitMoodAnxiousOverlay").resizable()
                        }
                    }
                    .frame(width: 480 * scale, height: 320 * scale)
                    .position(x: center + 4 * scale, y: 160 * scale)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var slider: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let thumbX = center(of: current, width: width)
            let railY = labelLineHeight + 41

            ZStack {
                rail(width: width).position(x: width / 2, y: railY)
                Image("PrevisitMoodThumb")
                    .resizable()
                    .frame(width: 60, height: 44)
                    .position(x: thumbX, y: railY)
                thumbLabel.position(x: thumbX, y: (labelLineHeight + 13) / 2)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                select(closestStop(to: value.location.x, width: width))
            })
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragging) { value, state, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = closestStop(to: value.location.x, width: width).state
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        select(closestStop(to: value.location.x, width: width))
                    }
            )
        }
        .frame(height: labelLineHeight + 63)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진료 전 상태")
        .accessibilityValue(selection == nil ? "선택 안 됨" : current.label)
        .accessibilityAdjustableAction { direction in
            let index = Self.stops.firstIndex { $0.state == selection }
            switch direction {
            case .increment:
                select(Self.stops[min((index ?? -1) + 1, Self.stops.count - 1)])
            case .decrement:
                select(Self.stops[max((index ?? 1) - 1, 0)])
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier("previsit.mood.slider")
    }

    private func rail(width: CGFloat) -> some View {
        Capsule()
            .fill(AppColors.Semantic.Chart.track)
            .frame(width: width, height: 20)
            .overlay {
                HStack(spacing: 0) {
                    ForEach(Self.stops.indices, id: \.self) { index in
                        Image("PrevisitMoodTrackDot")
                            .resizable()
                            .frame(width: 8, height: 8)
                        if index < Self.stops.count - 1 { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, 8)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(current.color)
                    .frame(width: width * current.fillWidth)
            }
    }

    private var thumbLabel: some View {
        VStack(spacing: 0) {
            Text(isAwaitingSelection ? "선택" : current.label)
                .appTypography(.labelLarge)
                .foregroundStyle(AppColors.Semantic.Text.inverse)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(minHeight: labelLineHeight + 8)
                .background(AppColors.Semantic.Text.sub, in: Capsule())
            Image("PrevisitMoodLabelTail")
                .resizable()
                .frame(width: 6.9282, height: 5)
                .rotationEffect(.degrees(180))
        }
    }

    private func center(of stop: Stop, width: CGFloat) -> CGFloat {
        let inset = min(24, width / 2)
        let center = inset + (width - 2 * inset) * stop.thumbPosition
        return layoutDirection == .rightToLeft ? width - center : center
    }

    private func closestStop(to location: CGFloat, width: CGFloat) -> Stop {
        Self.stops.min {
            abs(center(of: $0, width: width) - location) < abs(center(of: $1, width: width) - location)
        } ?? Self.stops[0]
    }

    private func select(_ stop: Stop) {
        guard stop.state != selection else { return }
        onSelect(stop.state)
    }
}
