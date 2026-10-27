import SwiftUI

struct TermsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var title = "약관"
    var content: String? = nil
    var version: String? = nil
    var effectiveDate: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let version { Text("약관 버전 \(version)") }
                        if let effectiveDate { Text("시행일 \(effectiveDate)") }
                    }
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                    VStack(alignment: .leading, spacing: 14) {
                        Text(title).appTypography(.labelLarge)
                            .accessibilityAddTraits(.isHeader)
                        Text(content ?? "약관 본문을 준비하고 있어요.")
                            .appTypography(.bodySmall)
                            .foregroundStyle(AppColors.Semantic.Text.sub)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.Surface.control, in: RoundedRectangle(cornerRadius: 20))
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, AppSpacing.section)
            }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
            .background(AppColors.Semantic.Background.surface.ignoresSafeArea())
            .foregroundStyle(AppColors.Semantic.Text.default)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(AppColors.Semantic.Text.sub)
                }
            }
        }
    }
}

#Preview { TermsDetailView() }
