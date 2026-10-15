import SwiftUI
import UIKit

struct SymptomCallWaitingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: CareCallScreenState
    @State private var hasStarted = false
    private let onClose: (() -> Void)?
    private let onStart: (() -> Void)?
    private let onPostpone: (() -> Void)?
    private let onSwitchToText: (() -> Void)?

    init(state: CareCallScreenState? = nil,
         onStart: (() -> Void)? = nil, onPostpone: (() -> Void)? = nil,
         onSwitchToText: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        _state = State(initialValue: state ?? CareCallScreenState())
        self.onStart = onStart
        self.onClose = onClose
        self.onPostpone = onPostpone
        self.onSwitchToText = onSwitchToText
    }

    var body: some View {
        Group {
            if state.canStart {
                CareCallIncomingView(
                    canAnswer: !hasStarted,
                    onAnswer: onStart.map { start in { hasStarted = true; start() } },
                    onEnd: close,
                    onPostpone: onPostpone,
                    onSwitchToText: onSwitchToText
                )
            } else {
                preparationPlaceholder
            }
        }
        .onAppear { state.onAction?(.prepare) }
        .onDisappear { state.onAction?(.cancel) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state.onAction?(.prepare) }
        }
    }

    // 하이파이 미제공 상태: 사용자가 승인한 동작 검증용 최소 UI입니다.
    private var preparationPlaceholder: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("케어콜 준비 · 임시 화면").font(.headline)
                Text("AI 음성으로 안내합니다")
                if state.isPreparing { ProgressView() }
                Text(statusTitle)
                Text(statusDescription)
                if state.preparation == .microphoneDenied {
                    Button("설정에서 마이크 허용하기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                if state.preparation == .failed || state.preparation == .modelLoadFailed || state.preparation == .microphoneDenied {
                    Button("다시 준비하기") { state.onAction?(.prepare) }
                }
                Button("10분 미루기") { onPostpone?() }.disabled(onPostpone == nil)
                Button("채팅으로 전환") { onSwitchToText?() }.disabled(onSwitchToText == nil)
                Button("종료", action: close)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("carecall.preparationStatus")
        .navigationBarBackButtonHidden()
    }

    private func close() {
        state.onAction?(.cancel)
        if let onClose { onClose() } else { dismiss() }
    }

    private var statusTitle: String {
        switch state.preparation {
        case .idle: "대화를 준비할게요"
        case .preparing(.permissions): "음성 대화 권한을 확인하고 있어요"
        case .preparing(.model): "학로가 대화를 준비하고 있어요"
        case .preparing(.speechAssets): "음성 인식을 준비하고 있어요"
        case .ready: "대화할 준비가 됐어요"
        case .microphoneDenied: "마이크 권한이 필요해요"
        case .modelMissing: "AI 모델을 사용할 수 없어요"
        case .modelLoadFailed: "AI 모델을 불러오지 못했어요"
        case .speechRecognitionUnsupported: "한국어 음성 인식을 사용할 수 없어요"
        case .failed: "대화를 준비하지 못했어요"
        case .unavailable: "대화 기능을 준비하고 있어요"
        }
    }

    private var statusDescription: String {
        switch state.preparation {
        case .idle, .preparing(.permissions): "학로와 이야기할 수 있도록 준비 상태를 확인해요."
        case .preparing(.model): "처음 준비할 때에는 시간이 조금 걸릴 수 있어요."
        case .preparing(.speechAssets): "음성 데이터를 확인하고 인식기를 준비하고 있어요. 다운로드가 필요할 수 있어요."
        case .ready: "오늘 하루는 어땠나요? 학로에게 편하게 이야기해 주세요."
        case .microphoneDenied: "설정에서 ToDoc의 마이크 사용을 허용해 주세요."
        case .modelMissing: "이 기기에서 필요한 AI 모델을 사용할 수 없어 대화를 시작할 수 없어요."
        case .modelLoadFailed: "대화에 필요한 모델을 준비하지 못했어요. 잠시 후 다시 시도해 주세요."
        case .speechRecognitionUnsupported: "이 기기에서는 한국어 음성 인식을 지원하지 않아요."
        case .failed: "잠시 후 다시 시도해 주세요."
        case .unavailable: "준비가 끝나면 학로와 대화를 시작할 수 있어요."
        }
    }
}


#Preview("서비스 미연결") { NavigationStack { SymptomCallWaitingView() } }
