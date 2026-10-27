import SwiftUI

extension AppCards {
    /// Figma Note Card. 본문에 Text 또는 입력 컴포넌트를 넣을 수 있습니다.
    struct NoteCard<Content: View>: View {
        private let to: String?
        private let from: String?
        private let content: Content

        init(to: String? = nil, from: String? = nil, @ViewBuilder content: () -> Content) {
            self.to = to
            self.from = from
            self.content = content()
        }

        init(_ text: String, to: String? = nil, from: String? = nil) where Content == Text {
            self.init(to: to, from: from) { Text(text) }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let to {
                    Text(to)
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                }
                content
                    .appTypography(.body)
                    .foregroundStyle(AppColors.Semantic.Text.default)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let from {
                    Text(from)
                        .appTypography(.caption)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.Semantic.Background.surface,
                        in: RoundedRectangle(cornerRadius: 30))
        }
    }
}
