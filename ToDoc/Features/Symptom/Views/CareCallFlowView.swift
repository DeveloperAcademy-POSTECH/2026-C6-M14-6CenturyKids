import SwiftUI

/// 화면 이동만 수행합니다. 화면이 나타나면 로그인 환자의 ViewModel을 준비하고, 권한/엔진 준비·대화 상태는 ViewModel이 제공합니다.
struct CareCallFlowView: View {
    @State private var viewModel: CareCallViewModel?
    @State private var connectionState = ConnectionState.loading
    @State private var hasEntered = false
    @Environment(\.dependencyContainer) private var container
    var onClose: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    private enum ConnectionState {
        case loading
        case signedOut
        case patientUnavailable
        case failed
    }

    var body: some View {
        Group {
            if let viewModel {
                flow(viewModel)
            } else {
                switch connectionState {
                case .loading:
                    ProgressView("케어콜을 준비하고 있어요")
                case .signedOut:
                    ContentUnavailableView("로그인이 필요해요", systemImage: "person.crop.circle",
                                           description: Text("케어콜을 이용하려면 로그인해 주세요."))
                case .patientUnavailable:
                    ContentUnavailableView("환자 계정을 찾지 못했어요", systemImage: "person.crop.circle.badge.questionmark")
                case .failed:
                    ContentUnavailableView {
                        Label("케어콜을 열 수 없어요", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("잠시 후 다시 시도해 주세요.")
                    } actions: {
                        Button("다시 시도") {
                            Task { await loadViewModelIfNeeded() }
                        }
                    }
                }
            }
        }
        .task { await loadViewModelIfNeeded() }
    }

    @ViewBuilder
    private func flow(_ viewModel: CareCallViewModel) -> some View {
        if hasEntered {
            SymptomRecordView(state: viewModel.conversation, onClose: onClose, onShowRecord: onShowRecord, onHome: onHome)
        } else {
            SymptomCallWaitingView(state: viewModel.preparation, onStart: { enter(.voice) },
                onPostpone: onPostpone, onSwitchToText: { enter(.text) }, onClose: onClose)
        }
    }

    private func enter(_ mode: SymptomConversationMode) {
        viewModel?.conversation.onAction?(.switchMode(mode)); hasEntered = true
    }

    @MainActor
    private func loadViewModelIfNeeded() async {
        guard viewModel == nil else { return }
        guard let container else {
            connectionState = .failed
            return
        }

        connectionState = .loading
        let client = container.supabaseProvider.client
        let authRepository = SupabaseAuthRepository(client: client)

        do {
            let userId = try await authRepository.getCurrentUserId()
            guard !Task.isCancelled else { return }
            guard let patient = try await SupabasePatientRepository(client: client).findById(userId) else {
                connectionState = .patientUnavailable
                return
            }
            guard !Task.isCancelled else { return }
            viewModel = try container.makeCareCallViewModel(patientId: patient.user.id)
        } catch is CancellationError {
            return
        } catch {
            connectionState = authRepository.isSignedIn() ? .failed : .signedOut
        }
    }
}
#Preview { NavigationStack { CareCallFlowView() } }
