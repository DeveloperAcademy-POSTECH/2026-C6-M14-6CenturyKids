import SafariServices
import SwiftUI

struct DocumentWebView: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var address: String

    private var url: URL? {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    var body: some View {
        if OfflineMode.isOn {
            // 기기에만 저장하는 모드에서는 웹페이지를 열지 않고 안내 글만 보여 준다
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("오프라인 체험 안내").font(.title2.bold())
                        Text("지금은 계정이나 서버 연결 없이 사용하고 있어요. 진료 전 기록, 통증 기록, 증상 대화와 프로필은 이 기기에만 저장돼요.")
                        Text("기록은 다른 기기로 옮겨지지 않고, 앱을 삭제하면 함께 삭제돼요. 설정의 관리자 메뉴에서 체험 기록을 지울 수 있어요.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
            }
        } else if let url {
            DocumentSafariView(url: url)
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "\(title)을 열 수 없어요",
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

private struct DocumentSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview("주소 오류") {
    DocumentWebView(title: "이용약관", address: "")
}
