import SwiftUI

extension AppInputs {
    /// Figma Segmented Control. 원본의 2·3개 항목을 같은 너비로 배치합니다.
    struct SegmentedControl<Value: Hashable>: View {
        private let title: String
        private let options: [Value]
        private let label: (Value) -> String
        @Binding private var selection: Value

        init(_ title: String, options: [Value], selection: Binding<Value>,
             label: @escaping (Value) -> String) {
            self.title = title
            self.options = options
            self._selection = selection
            self.label = label
        }

        var body: some View {
            HStack(spacing: 16) {
                ForEach(options, id: \.self) { option in
                    SwiftUI.Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .appTypography(selection == option ? .labelLarge : .body)
                            .foregroundStyle(selection == option ? AppColors.Semantic.Text.inverse
                                             : AppColors.Semantic.Text.sub)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 55)
                            .background {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: 40)
                                        .fill(AppColors.Semantic.Text.sub)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 40)
                                                .strokeBorder(SegmentedPalette.selectedBorder, lineWidth: 2)
                                        }
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 40))
                    }
                    .buttonStyle(AppActions.PressStyle())
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
            .padding(8)
            .frame(minHeight: 71)
            .background(AppColors.Semantic.Background.secondary,
                        in: RoundedRectangle(cornerRadius: 40))
            .overlay {
                RoundedRectangle(cornerRadius: 40)
                    .strokeBorder(SegmentedPalette.border, lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }

    /// Figma가 직접 지정한 테두리 색상입니다. Semantic 토큰이 생기면 이곳만 바꿉니다.
    private enum SegmentedPalette {
        static let border = LinearGradient(
            colors: [Color(red: 223 / 255, green: 223 / 255, blue: 223 / 255),
                     Color(red: 253 / 255, green: 253 / 255, blue: 253 / 255)],
            startPoint: .top, endPoint: .bottom
        )
        static let selectedBorder = LinearGradient(
            colors: [Color(red: 120 / 255, green: 120 / 255, blue: 120 / 255),
                     Color(red: 91 / 255, green: 87 / 255, blue: 91 / 255)],
            startPoint: .top, endPoint: .bottom
        )
    }
}
