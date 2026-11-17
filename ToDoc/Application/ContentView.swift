import SwiftUI

@MainActor
struct ContentView: View {
    @State private var router: AppRouter
    @State private var isReady = false
    @State private var storageError: String?
    private let container: DependencyContainer

    init(container: DependencyContainer, router: AppRouter) {
        self.container = container
        _router = State(initialValue: router)
    }

    var body: some View {
        Group {
            if isReady {
                PatientFlowCompositionView(container: container, patientId: OfflineProfile.id)
            } else if let storageError {
                ContentUnavailableView {
                    Label("기기 저장소를 열 수 없어요", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(storageError)
                } actions: {
                    Button("다시 시도") { Task { await prepare() } }
                }
            } else {
                ProgressView("기기 기록을 준비하고 있어요")
            }
        }
        .environment(router)
        .task { await prepare() }
        .onOpenURL { url in
            if let deepLink = DeepLink(url: url) { router.handle(deepLink) }
        }
    }

    private func prepare() async {
        do {
            try OfflineProfile.prepare(store: container.localStore)
            let pending = FilePendingCareCallRepository()
            if let local = container.symptomRepository as? LocalSymptomRepository {
                for answer in try pending.findAll(patientId: OfflineProfile.id) {
                    _ = try local.savePending(answer.record, attemptID: answer.id, merge: CareCallViewModel.merge)
                    try pending.delete(id: answer.id, patientId: OfflineProfile.id)
                }
            }
            storageError = nil
            isReady = true
        } catch {
            storageError = "저장 공간과 기기 잠금 상태를 확인한 뒤 다시 시도해 주세요. 기존 기록은 그대로 유지돼요."
        }
    }
}
