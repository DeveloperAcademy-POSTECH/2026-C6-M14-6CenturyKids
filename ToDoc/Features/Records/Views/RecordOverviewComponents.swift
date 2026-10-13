import SwiftUI

struct RecordTextStyle: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight = .medium) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body); self.weight = weight
    }
    func body(content: Content) -> some View {
        content.font(Font(AppTypography.Style.caption.font(at: size)).weight(weight))
    }
}

/// 점수와 미기록을 구분하며, 그래프 길이만 유효 범위로 제한합니다.
/// 표시하는 숫자는 외부 집계 입력을 반올림해 그릴 뿐 저장값을 바꾸지 않습니다.
enum RecordDisplay {
    static func number(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "미제공" }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
    static func fraction(_ value: Double?, maximum: Double) -> CGFloat {
        guard let value, value.isFinite else { return 0 }
        return CGFloat(min(max(value / maximum, 0), 1))
    }
    static let paleGreen = Color(red: 240 / 255, green: 244 / 255, blue: 232 / 255)
    static let green = Color(red: 166 / 255, green: 223 / 255, blue: 66 / 255)
    static let darkGreen = Color(red: 128 / 255, green: 182 / 255, blue: 35 / 255)
}

struct RecordOverviewCard<Graphic: View, Content: View>: View {
    let label: String
    let value: String
    let action: (() -> Void)?
    @ViewBuilder var graphic: () -> Graphic
    @ViewBuilder var content: () -> Content
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Button { action?() } label: {
            Group {
                if typeSize.isAccessibilitySize { vertical }
                else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 28) {
                            graphic().frame(width: 80, height: 80)
                            content().frame(minWidth: 115, maxWidth: .infinity, alignment: .leading)
                            arrow
                        }
                        vertical
                    }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18.5)
            .frame(maxWidth: .infinity, minHeight: 117, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).disabled(action == nil)
        .accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityValue(value)
    }
    private var vertical: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { graphic().frame(width: 80, height: 80); Spacer(); arrow }
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var arrow: some View {
        Image("RecordsDetailArrow").frame(width: 45, height: 44).accessibilityHidden(true)
    }
}

struct RecordPainMiniChart: View {
    let data: RecordOverviewSnapshot.Pain?
    var body: some View {
        HStack(alignment: .bottom, spacing: 9) {
            bar(data?.averageBefore, color: Color(white: 0.90), border: Color(white: 0.75), text: Color(white: 0.42))
            bar(data?.averageAfter, color: AppColors.primary, border: RecordDisplay.green, text: RecordDisplay.darkGreen)
                .overlay(alignment: .top) {
                    if let difference = data?.difference, difference != 0 {
                        Image("RecordsPainChangeArrow").frame(width: 16, height: 15.5991)
                            .rotationEffect(.degrees(difference < 0 ? 180 : 0)).offset(y: -20)
                    }
                }
        }
        .padding(.bottom, 6).frame(width: 80, height: 80, alignment: .bottom).accessibilityHidden(true)
    }
    private func bar(_ score: Double?, color: Color, border: Color, text: Color) -> some View {
        let height = 22.5 + 46 * RecordDisplay.fraction(score, maximum: 10)
        return ZStack(alignment: .bottom) {
            Capsule().fill(score == nil ? RecordDisplay.paleGreen : color)
            if let score {
                // 0점도 숫자를 표시하고, nil이면 값을 만들지 않습니다.
                Text(RecordDisplay.number(score)).font(Font(AppTypography.Style.caption.font(at: 15.75)).weight(.semibold))
                    .foregroundStyle(text).padding(.bottom, 1)
            }
        }
        .frame(width: 22.5, height: score == nil ? 22.5 : height)
        .overlay(alignment: .top) {
            if score != nil, height >= 42 {
                Circle().fill(.white).overlay { Circle().strokeBorder(border, lineWidth: 4) }.frame(width: 22.5, height: 22.5)
            }
        }
    }
}

struct RecordSymptomMiniChart: View {
    let score: Double?
    var body: some View {
        VStack(spacing: 6) {
            Text(score.map { RecordDisplay.number($0) } ?? "—")
                .font(Font(AppTypography.Style.caption.font(at: 15)).weight(.bold)).foregroundStyle(RecordDisplay.darkGreen)
            ZStack(alignment: .leading) {
                Capsule().fill(RecordDisplay.paleGreen)
                if score != nil {
                    Capsule().fill(AppColors.primary).frame(width: 24 + 46 * RecordDisplay.fraction(score, maximum: 10))
                    Circle().fill(.white).overlay { Circle().strokeBorder(RecordDisplay.green, lineWidth: 5) }
                        .frame(width: 24, height: 24).offset(x: 46 * RecordDisplay.fraction(score, maximum: 10))
                }
            }.frame(width: 70, height: 24)
            HStack { Text("0"); Spacer(); Text("10") }
                .font(Font(AppTypography.Style.caption.font(at: 12))).foregroundStyle(Color(white: 0.82)).frame(width: 70)
        }.frame(width: 80, height: 80).accessibilityHidden(true)
    }
}
