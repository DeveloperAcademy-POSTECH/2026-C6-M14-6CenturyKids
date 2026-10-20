import SwiftUI

/// 화면 이동만 수행합니다. 로그인 환자 조회·권한/엔진 준비·대화 상태는 ViewModel이 제공합니다.
/// ViewModel은 화면에 들어올 때 만들어, 화면을 나가면 AI 모델과 함께 풀립니다.
struct CareCallFlowView: View {
    @State private var viewModel: CareCallViewModel?
    @State private var cannotOpen = false
    @State private var hasEntered = false
    var makeViewModel: (() throws -> CareCallViewModel)?
    var onClose: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.connectionState {
                case .ready:
                    flow(viewModel)
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
                            Task { await viewModel.loadPatient() }
                        }
                    }
                }
            } else if cannotOpen {
                // 케어콜 설정 파일을 읽지 못함 (다시 시도해도 같다)
                ContentUnavailableView("케어콜을 열 수 없어요", systemImage: "exclamationmark.circle")
            } else {
                ProgressView("케어콜을 준비하고 있어요")
            }
        }
        .task { await loadViewModel() }
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

    private func loadViewModel() async {
        if viewModel == nil {
            guard let made = try? makeViewModel?() else {
                cannotOpen = true
                return
            }
            viewModel = made
        }
        await viewModel?.loadPatient()
    }
}
#Preview { NavigationStack { CareCallFlowView() } }
