import SwiftUI

extension AppNavigation {
    struct QuestionHeader: View {
        private let question: String
        private let sub: String?
        private let progress: Double?

        init(_ question: String, sub: String? = nil, progress: Double? = nil) {
            self.question = question
            self.sub = sub
            self.progress = progress
        }

        var body: some View {
            VStack(spacing: 32) {
                if let progress {
                    ProgressBar(value: progress)
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
