import SwiftUI

/// 화면 이동만 수행합니다. 권한/엔진 준비·대화 상태는 외부에서 제공합니다.
struct CareCallFlowView: View {
    @State var preparation = CareCallScreenState()
    @State var conversation = SymptomScreenState()
    @State private var hasEntered = false
    var onClose: (() -> Void)?
    var onPostpone: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    var body: some View {
        if hasEntered {
            SymptomRecordView(state: conversation, onClose: onClose, onShowRecord: onShowRecord, onHome: onHome)
        } else {
            SymptomCallWaitingView(state: preparation, onStart: { enter(.voice) },
                onPostpone: onPostpone, onSwitchToText: { enter(.text) }, onClose: onClose)
        }
    }
    private func enter(_ mode: SymptomConversationMode) {
        conversation.onAction?(.switchMode(mode)); hasEntered = true
    }
}
#Preview { NavigationStack { CareCallFlowView() } }
