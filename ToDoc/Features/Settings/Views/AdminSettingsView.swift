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

/// 시연용 관리자 기능 목록. 누르면 한 번 확인한 뒤 실행하고 결과를 알려 준다.
struct AdminSettingsView: View {
    enum Action: String, Identifiable {
        case painSkip, resetSymptom, resetPrevisit, seedMockData, clearAll

        var id: String { rawValue }
        var title: String {
            switch self {
            case .painSkip: "통증 1시간 스킵"
            case .resetSymptom: "증상 초기화"
            case .resetPrevisit: "진료 전 기록 초기화"
            case .seedMockData: "목데이터 채우기"
            case .clearAll: "목데이터 지우기"
            }
        }
        var question: String {
            switch self {
            case .painSkip: "기다리는 통증 기록을 10초 뒤에 기록할 수 있게 바꿀까요?"
            case .resetSymptom: "오늘 증상 기록을 지울까요? 되돌릴 수 없어요."
            case .resetPrevisit: "오늘 보낸 진료 전 기록을 지울까요? 되돌릴 수 없어요."
            case .seedMockData: "10월 16일~11월 19일의 증상·통증·진료 전 기록을 지우고 목데이터로 다시 채울까요? 되돌릴 수 없어요."
            case .clearAll: "이 계정의 모든 증상·통증·진료 전 기록을 지울까요? 날짜와 상관없이 전부 지워지고 되돌릴 수 없어요."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(DemoAdminService.self) private var service: DemoAdminService?
    @State private var confirming: Action?
    @State private var running: Action?
    @State private var result: String?
    @AppStorage(DemoCareCallPlan.enabledKey) private var demoCareCall = true
    @AppStorage(FoundationModelsCareCallAdapter.warmSessionKey) private var warmSession = true
    @AppStorage(FoundationModelsCareCallAdapter.speculationKey) private var speculation = false

    var body: some View {
        SettingsScreen(title: "관리자 설정", cancel: { dismiss() }) {
            SettingsSection(title: "", footer: "켜면 그날 처음 증상 기록할 때 7개 중 3개만 랜덤으로 묻고, 나머지 4개는 목데이터로 채워요. 다음 증상 기록부터 적용돼요.") {
                Toggle(isOn: $demoCareCall) {
                    Text("증상 데모 흐름").settingsText()
                }
                .tint(AppColors.primary)
                .padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
                .accessibilityIdentifier("settings.admin.demoCareCall")
            }
            SettingsSection(title: "", footer: "켜면 다음 AI 분석용 세션을 미리 만들어 데워 둬요. 끄면 예전처럼 분석할 때 만들어요. 시간은 Console 앱에서 FMTiming으로 볼 수 있어요.") {
                Toggle(isOn: $warmSession) {
                    Text("AI 세션 미리 데우기").settingsText()
                }
                .tint(AppColors.primary)
                .padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
                .accessibilityIdentifier("settings.admin.warmSession")
            }
            SettingsSection(title: "", footer: "켜면 환자가 말을 멈춘 것 같을 때 문장이 확정되기 전에 AI 분석을 미리 시작해요. 문장이 달라지면 버리고 다시 분석해요. Console 앱에서 [미리]로 볼 수 있어요.") {
                Toggle(isOn: $speculation) {
                    Text("말 끝나기 전에 미리 분석하기").settingsText()
                }
                .tint(AppColors.primary)
                .padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
                .accessibilityIdentifier("settings.admin.speculation")
            }
            SettingsSection(title: "") {
                row(.painSkip, subtitle: nil)
                SettingsDivider()
                row(.resetSymptom, subtitle: "오늘 기록만 지워요")
                SettingsDivider()
                row(.resetPrevisit, subtitle: "오늘 기록만 지워요")
            }
            SettingsSection(title: "") {
                row(.seedMockData, subtitle: "10/16~11/19 증상·통증, 10/16·11/6 진료 전 기록")
                SettingsDivider()
                row(.clearAll, subtitle: "모든 기록을 지워요")
            }
            if service == nil {
                SettingsFeedback(error: "로그인한 환자 화면에서만 쓸 수 있어요.")
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .alert(confirming?.title ?? "", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
               presenting: confirming) { action in
            Button("취소", role: .cancel) {}
            Button("실행", role: action == .painSkip ? nil : .destructive) { run(action) }
        } message: { action in
            Text(action.question)
        }
        .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("확인", role: .cancel) {}
        }
    }

    private func row(_ action: Action, subtitle: String?) -> some View {
        Button { confirming = action } label: {
            HStack {
                SettingsRow(title: action.title, subtitle: subtitle, chevron: running != action)
                if running == action { ProgressView().padding(.trailing, 16) }
            }
        }
        .disabled(service == nil || running != nil)
        .accessibilityIdentifier("settings.admin.\(action.rawValue)")
    }

    private func run(_ action: Action) {
        guard let service else { return }
        running = action
        Task {
            defer { running = nil }
            do {
                result = switch action {
                case .painSkip: try await service.skipPainWait()
                case .resetSymptom: try await service.resetTodaySymptoms()
                case .resetPrevisit: try await service.resetTodayPrevisit()
                case .seedMockData: try await service.seedMockData()
                case .clearAll: try await service.clearAllRecords()
                }
            } catch {
                result = error.localizedDescription
            }
        }
    }
}

#Preview { NavigationStack { AdminSettingsView() } }
