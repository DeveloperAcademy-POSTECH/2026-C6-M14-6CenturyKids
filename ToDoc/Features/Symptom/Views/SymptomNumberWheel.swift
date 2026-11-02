import SwiftUI

/// Figma 수동 입력의 큰 선택 숫자와 위/아래 선택지를 재현합니다.
struct SymptomNumberWheel: View {
    let title: String
    let labels: [String]
    let selectedIndex: Int
    var hasSelection = true
    let onSelect: (Int) -> Void
    @Environment(\.isEnabled) private var isEnabled
    /// 끌기를 시작할 때의 선택. 끄는 동안 이 값에서 끈 거리만큼 넘긴다
    @State private var dragStart: Int?

    /// 이만큼 끌면 숫자 하나를 넘긴다
    private static let step: CGFloat = 62

    private var index: Int { min(max(0, selectedIndex), max(0, labels.count - 1)) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 244 / 255))
                    .frame(height: 109)
                    .position(x: geometry.size.width / 2, y: 199)
                ForEach(-2...1, id: \.self) { offset in
                    let candidate = index + offset
                    if labels.indices.contains(candidate) {
                        Text(labels[candidate])
                            .font(Font(AppTypography.Style.heading.font(at: offset == 0 ? 100 : 40)))
                            .foregroundStyle(offset == 0 ? .black : Color(white: offset == -2 ? 235 / 255 : 206 / 255))
                            .tracking(offset == 0 ? -1 : 0)
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: offset == 0 ? 109 : 52)
                            .position(x: geometry.size.width / 2, y: position(for: offset))
                    }
                }
            }
            .contentShape(Rectangle())
            // 닿자마자 잡아야 바깥 질문 화면의 스크롤이 끌기를 가져가지 않는다. 그래서 누르기도 여기서 처리한다
            .highPriorityGesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = dragStart ?? index
                    dragStart = start
                    // 손가락을 따라 넘긴다: 위로 끌면 아래 숫자(큰 수)가 가운데로 온다. 닿기만 해서는 고른 것으로 치지 않는다
                    let steps = Int((-value.translation.height / Self.step).rounded())
                    if steps != 0 || index != start { choose(start + steps) }
                }
                .onEnded { value in
                    defer { dragStart = nil }
                    guard abs(value.translation.height) < 10, abs(value.translation.width) < 10 else { return }
                    choose(index + tappedOffset(at: value.location.y))
                })
        }
        .frame(height: 312)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(hasSelection && labels.indices.contains(index) ? labels[index] : "미선택")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: choose(index + 1)
            case .decrement: choose(index - 1)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "선택") { choose(index) }
    }

    private func choose(_ candidate: Int) {
        guard isEnabled, !labels.isEmpty else { return }
        onSelect(min(max(0, candidate), labels.count - 1))
    }

    /// 누른 자리에서 가장 가까운 숫자 (보이는 숫자만)
    private func tappedOffset(at y: CGFloat) -> Int {
        (-2...1).filter { labels.indices.contains(index + $0) }
            .min { abs(position(for: $0) - y) < abs(position(for: $1) - y) } ?? 0
    }

    private func position(for offset: Int) -> CGFloat {
        switch offset {
        case -2: 47
        case -1: 110
        case 0: 198
        default: 288
        }
    }
}
