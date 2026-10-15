import SwiftUI

/// Figma 수동 입력의 큰 선택 숫자와 위/아래 선택지를 재현합니다.
struct SymptomNumberWheel: View {
    let title: String
    let labels: [String]
    let selectedIndex: Int
    var hasSelection = true
    let onSelect: (Int) -> Void
    @Environment(\.isEnabled) private var isEnabled

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
                        Button { choose(candidate) } label: {
                            Text(labels[candidate])
                                .font(Font(AppTypography.Style.heading.font(at: offset == 0 ? 100 : 40)))
                                .foregroundStyle(offset == 0 ? .black : Color(white: offset == -2 ? 235 / 255 : 206 / 255))
                                .tracking(offset == 0 ? -1 : 0)
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: offset == 0 ? 109 : 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .position(x: geometry.size.width / 2, y: position(for: offset))
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 15).onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                let steps = max(1, Int(abs(value.translation.height) / 62))
                choose(index + (value.translation.height < 0 ? steps : -steps))
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

    private func position(for offset: Int) -> CGFloat {
        switch offset {
        case -2: 47
        case -1: 110
        case 0: 198
        default: 288
        }
    }
}
