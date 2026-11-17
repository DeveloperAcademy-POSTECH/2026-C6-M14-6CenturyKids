import SwiftUI

/// 기기에만 저장하는 모드의 첫 화면입니다. 로그인 없이 고정된 체험자로 바로 들어갑니다.
struct OfflineRootView: View {
    let container: DependencyContainer
    @State private var isReady = false
    @State private var failed = false

    var body: some View {
        Group {
            if isReady {
                PatientFlowCompositionView(container: container, patientId: OfflineProfile.id)
                    .task { await LocalNotificationAdapter.schedulePainReminders() }
            } else if failed {
                ContentUnavailableView {
                    Label("기기 저장소를 열 수 없어요", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("저장 공간과 기기 잠금 상태를 확인한 뒤 다시 시도해 주세요. 기존 기록은 그대로 유지돼요.")
                } actions: {
                    Button("다시 시도", action: prepare)
                }
            } else {
                // 빈 Group에는 아래 task가 붙지 않아 준비가 시작되지 않는다
                Color.clear
            }
        }
        .task { prepare() }
    }

    private func prepare() {
        guard let store = container.localStore else { return }
        do {
            try OfflineProfile.prepare(store: store)
            failed = false
            isReady = true
        } catch {
            failed = true
        }
    }
}
