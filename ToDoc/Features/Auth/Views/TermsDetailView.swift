import SwiftUI

struct TermsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var title = "약관"
    var content: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content ?? "약관 본문을 준비하고 있어요.")
                    .appTextStyle(.label)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 24)
            }
            .appScreenStyle()
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

#Preview { TermsDetailView() }
