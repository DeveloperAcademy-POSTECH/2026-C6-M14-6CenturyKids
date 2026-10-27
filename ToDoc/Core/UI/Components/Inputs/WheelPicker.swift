import SwiftUI

extension AppInputs {
    /// Figma Wheel Picker. 관성 스크롤·선택·접근성은 iOS의 기본 휠을 사용합니다.
    /// 원본의 비균등 행 높이는 시스템 휠의 동일한 행 간격으로 표시됩니다.
    /// 접근성 글자 크기에서는 고정된 native 행 안에서 겹치지 않도록 메뉴로 선택합니다.
    struct WheelPicker<Value: Hashable>: View {
        private let title: String
        private let options: [Value]
        private let unit: String?
        private let label: (Value) -> String
        @Binding private var selection: Value
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 216

        init(_ title: String, options: [Value], selection: Binding<Value>, unit: String? = nil,
             label: @escaping (Value) -> String) {
            self.title = title
            self.options = options
            self._selection = selection
            self.unit = unit
            self.label = label
        }

        var body: some View {
            VStack(spacing: 8) {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibleMenu
                } else {
                    wheel
                }

                if let unit {
                    Text(unit)
                        .appTypography(.label)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .accessibilityHidden(true)
                }
            }
            .frame(minWidth: 160)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(unit.map { "\(title), \($0)" } ?? title)
        }

        private var wheel: some View {
            SwiftUI.Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option))
                        .appTypography(selection == option ? .display : .title)
                        .foregroundStyle(selection == option ? AppColors.Semantic.Text.default
                                         : AppColors.Semantic.Text.disabled)
                        .tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: wheelHeight)
            .clipped()
        }

        private var accessibleMenu: some View {
            SwiftUI.Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .appTypography(.title)
            .tint(AppColors.Semantic.Text.default)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(AppColors.Semantic.Background.secondary,
                        in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
