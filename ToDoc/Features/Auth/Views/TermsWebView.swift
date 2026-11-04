import SafariServices
import SwiftUI

struct TermsWebView: View {
    @Environment(\.dismiss) private var dismiss
    var address = "https://nuarc.notion.site/socdoc-terms-of-use"

    private var url: URL? {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    var body: some View {
        if let url {
            TermsSafariView(url: url)
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "이용약관을 열 수 없어요",
                    systemImage: "exclamationmark.circle",
                    description: Text("웹페이지 주소를 찾을 수 없어요. 잠시 후 다시 시도해 주세요.")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
            }
        }
    }
}

private struct TermsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("주소 오류") {
    TermsWebView(address: "")
}
