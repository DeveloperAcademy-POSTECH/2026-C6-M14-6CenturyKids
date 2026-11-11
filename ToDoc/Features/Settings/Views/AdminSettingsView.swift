import SwiftUI

/// 시연용 관리자 설정 진입. 비밀번호가 맞으면 관리자 화면으로 간다.
struct SettingsAdminEntry: View {
    private static let password = "1120"
    @State private var input = ""
    @State private var asksPassword = false
    @State private var showsWrongPassword = false
    @State private var showsAdmin = false

    var body: some View {
        SettingsSection(title: "관리자") {
            Button { input = ""; asksPassword = true } label: {
                SettingsRow(title: "관리자 설정", chevron: true)
            }
            .accessibilityIdentifier("settings.admin")
        }
        .alert("관리자 비밀번호", isPresented: $asksPassword) {
            SecureField("비밀번호", text: $input)
                .keyboardType(.numberPad)
            Button("취소", role: .cancel) {}
            Button("확인") {
                if input == Self.password { showsAdmin = true } else { showsWrongPassword = true }
            }
        } message: {
            Text("비밀번호를 입력해 주세요.")
        }
        .alert("비밀번호가 맞지 않아요", isPresented: $showsWrongPassword) {
            Button("확인", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showsAdmin) { AdminSettingsView() }
    }
}

/// 시연용 관리자 기능 목록. 지금은 화면만 있고 누르면 아무 일도 하지 않는다.
struct AdminSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsScreen(title: "관리자 설정", cancel: { dismiss() }) {
            SettingsSection(title: "") {
                Button {} label: { SettingsRow(title: "통증 1시간 스킵", chevron: true) }
                    .accessibilityIdentifier("settings.admin.painSkip")
                SettingsDivider()
                Button {} label: { SettingsRow(title: "증상 초기화", subtitle: "오늘 기록만 지워요", chevron: true) }
                    .accessibilityIdentifier("settings.admin.resetSymptom")
                SettingsDivider()
                Button {} label: { SettingsRow(title: "진료 전 기록 초기화", subtitle: "오늘 기록만 지워요", chevron: true) }
                    .accessibilityIdentifier("settings.admin.resetPrevisit")
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview { NavigationStack { AdminSettingsView() } }
