import SwiftUI

/// Offline information for legacy document routes. Never opens a remote page.
struct DocumentWebView: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var address: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("오프라인 체험 안내").font(.title2.bold())
                    Text("이 버전은 계정이나 서버 연결 없이 사용해요. 진료 전 기록, 통증 기록, 증상 대화와 프로필은 이 기기에만 저장돼요.")
                    Text("기록은 다른 기기로 동기화되지 않으며 앱을 삭제하면 함께 삭제돼요. 설정의 관리자 메뉴에서 체험 기록을 지울 수 있어요.")
                }.padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
