import SwiftUI

extension AppNavigation {
    struct QuestionHeader: View {
        private let question: String
        private let sub: String?
        private let progress: Double?
        private let onClose: (() -> Void)?

        init(_ question: String, sub: String? = nil, progress: Double? = nil, onClose: (() -> Void)? = nil) {
            self.question = question
            self.sub = sub
            self.progress = progress
            self.onClose = onClose
        }

        var body: some View {
            VStack(spacing: 32) {
                if progress != nil || onClose != nil {
                    HStack(spacing: 16) {
                        if let onClose {
                            SwiftUI.Button("닫기", systemImage: "xmark", action: onClose)
                                .labelStyle(.iconOnly)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(AppColors.Semantic.Text.default)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .frame(width: 24, height: 8)
                        }
                        if let progress {
                            ProgressBar(value: progress)
                        }
                    }
                }

                VStack(spacing: 8) {
                    if let sub {
                        Text(sub)
                            .appTypography(.body)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                    Text(question)
                        .appTypography(.title)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .accessibilityAddTraits(.isHeader)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
