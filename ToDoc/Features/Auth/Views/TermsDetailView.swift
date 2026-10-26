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
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    if let version { Text("약관 버전 \(version)").appTextStyle(.caption) }
                    if let effectiveDate { Text("시행일 \(effectiveDate)").appTextStyle(.caption) }
                    Text(content ?? "약관 본문을 준비하고 있어요.").appTextStyle(.label)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, AppSpacing.section)
            }
            .appScreenStyle()
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

#Preview { TermsDetailView() }
