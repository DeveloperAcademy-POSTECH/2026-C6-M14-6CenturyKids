import SwiftUI

extension AppNavigation {
    /// Figma의 native/custom 선택은 미확정입니다. 기존 TabView와 연결하지 않은 custom 시안입니다.
    struct TabBar<Option: Hashable>: View {
        @Binding private var selection: Option
        private let options: [Option]
        private let title: (Option) -> String
        private let icon: (Option) -> Image

        /// 원본의 같은 너비 3개 탭을 타입이 있는 선택 값과 연결합니다.
        init(
            selection: Binding<Option>,
            options: (Option, Option, Option),
            title: @escaping (Option) -> String,
            icon: @escaping (Option) -> Image
        ) {
            _selection = selection
            self.options = [options.0, options.1, options.2]
            self.title = title
            self.icon = icon
        }

        var body: some View {
            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { index in
                    tab(options[index])
                }
            }
            .padding(4)
            .frame(minHeight: 64)
            .background(AppColors.Semantic.Background.surface, in: RoundedRectangle(cornerRadius: 999))
            .overlay {
                RoundedRectangle(cornerRadius: 999)
                    .strokeBorder(AppColors.Semantic.Border.default, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }

        private func tab(_ option: Option) -> some View {
            let selected = selection == option
            return SwiftUI.Button {
                selection = option
            } label: {
                VStack(spacing: 2) {
                    icon(option)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                    Text(title(option))
                        .appTypography(.caption)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(selected ? AppColors.Semantic.Text.default : AppColors.Semantic.Text.sub)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(selected ? AppColors.Semantic.Background.secondary : .clear, in: RoundedRectangle(cornerRadius: 999))
                .contentShape(RoundedRectangle(cornerRadius: 999))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(title(option)))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}
