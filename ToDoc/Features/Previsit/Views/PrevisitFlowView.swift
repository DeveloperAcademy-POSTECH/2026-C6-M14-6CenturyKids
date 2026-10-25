import SwiftUI

/// 기존 기록 조회만 부모가 주입합니다. 편지·기분 전송은 저장 계약이 있어야 연결합니다.
struct PrevisitFlowView: View {
    var doctorName = "선생님"
    var loadDays: (() async throws -> [PrevisitDay])?
    @State private var session: PrevisitSession
    @State private var records: PrevisitRecordState
    @State private var reloadID = 0
    @State private var showsDiscardConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init(doctorName: String = "선생님", session: PrevisitSession? = nil, loadDays: (() async throws -> [PrevisitDay])? = nil) {
        self.doctorName = doctorName
        self.loadDays = loadDays
        _session = State(initialValue: session ?? PrevisitSession())
        _records = State(initialValue: loadDays == nil ? .loaded([]) : .loading)
    }

    var body: some View {
        Group {
            if session.isWriting {
                PrevisitRecordView(doctorName: doctorName, onClose: close, session: session,
                                   records: records, onReload: { reloadID += 1 })
                    .task(id: reloadID) { await loadRecords() }
            } else {
                PrevisitPromptView(startTitle: session.hasDraft ? "이어서 작성하기" : nil,
                                   notice: "현재는 입력만 가능하며 서버에 저장·전송되지 않아요.",
                                   onStart: session.start, onClose: close,
                                   onDiscard: session.hasDraft ? { showsDiscardConfirmation = true } : nil)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("작성 내용을 지울까요?", isPresented: $showsDiscardConfirmation) {
            Button("유지하기", role: .cancel) { }
            Button("지우기", role: .destructive) { session.discard() }
        } message: {
            Text("선택한 기록과 편지, 기분을 모두 지워요.")
        }
    }

    private func close() { session.pause(); dismiss() }

    private func loadRecords() async {
        guard let loadDays else { return }
        records = .loading
        do {
            let days = try await loadDays()
            try Task.checkCancellation()
            session.refreshDays(days)
            records = .loaded(days)
        } catch {
            guard !Task.isCancelled else { return }
            records = .failed
        }
    }
}

#Preview("진료 전 대기 · 작성 가능 · 실제 전송 안 됨") {
    NavigationStack { PrevisitFlowView() }
}
