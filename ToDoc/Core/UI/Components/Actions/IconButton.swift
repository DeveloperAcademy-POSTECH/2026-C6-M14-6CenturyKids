import SwiftUI

extension AppActions {
    /// Figma의 Icon Button. 미정인 아이콘은 호출자가 이미지로 제공합니다.
    struct IconButton: View {
        enum Kind {
            case `default`, labeled
        }

        private let title: String
        private let icon: Image
        private let kind: Kind
        private let fill: Color
        private let action: () -> Void

        init(_ title: String, icon: Image, type: Kind = .default,
             fill: Color = AppColors.Semantic.Background.default, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.kind = type
            self.fill = fill
            self.action = action
        }

        var body: some View {
            SwiftUI.Button(action: action) {
                VStack(spacing: 8) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: diameter, height: diameter)
                        .background(fill, in: Circle())
                        .accessibilityHidden(true)

                    if case .labeled = kind {
                        Text(title)
                            .appTypography(.caption)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(Text(title))
        }

        private var diameter: CGFloat {
            switch kind {
            case .default: 44
            case .labeled: 64
            }
        }
    }
}
