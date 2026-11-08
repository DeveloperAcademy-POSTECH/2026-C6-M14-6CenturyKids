import SwiftUI
import UIKit

struct SymptomCallWaitingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: CareCallScreenState
    @State private var hasStarted = false
    @State private var dismissedPopup = false
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
            switch state.preparation {
            case .modelMissing, .modelLoadFailed, .failed:
                SymptomServiceErrorView(onRetry: { state.onAction?(.prepare) }, onHome: close)
            default:
                // 준비하는 동안에는 전화받기만 막는다 (10분 미루기·채팅으로 전환·종료는 된다)
                CareCallIncomingView(
                    canAnswer: state.canStart && !hasStarted,
                    onAnswer: onStart.map { start in { hasStarted = true; start() } },
                    onEnd: close,
                    onPostpone: onPostpone,
                    onSwitchToText: onSwitchToText
                )
                .accessibilityValue(state.isPreparing ? "통화를 준비하고 있어요" : "")
                .overlay { popup }
            }
        }
        .onAppear { state.onAction?(.prepare) }
        .onDisappear { state.onAction?(.cancel) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { state.onAction?(.prepare) }
        }
        .onChange(of: state.preparation) { dismissedPopup = false }
    }

    /// 음성 통화를 쓸 수 없을 때 알린다. 채팅으로 전환은 그대로 쓸 수 있다
    @ViewBuilder
    private var popup: some View {
        if !dismissedPopup {
            switch state.preparation {
            case .microphoneDenied:
                SymptomPopup.microphone(onConfirm: { dismissedPopup = true }, onSettings: openSettings)
            case .speechRecognitionUnsupported:
                SymptomPopup.service(onConfirm: { dismissedPopup = true }, onSettings: openSettings)
            default:
                EmptyView()
            }
        }
    }

    private func openSettings() {
        dismissedPopup = true
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func close() {
        state.onAction?(.cancel)
        if let onClose { onClose() } else { dismiss() }
    }
}


#Preview("서비스 미연결") { NavigationStack { SymptomCallWaitingView() } }
