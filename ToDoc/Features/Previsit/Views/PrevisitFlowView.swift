import SwiftUI

/// 작성 → 전송 완료 팝업 → 보낸 기록 보기. 시작 안내 바텀시트는 홈(PatientFlowView)이 띄웁니다.
/// 기존 기록 조회와 전송받을 ViewModel을 부모가 주입합니다. 서버 저장 계약은 아직 없어 letter가 메모리에 둡니다.
struct PrevisitFlowView: View {
    var doctorName = "선생님"
    var patientName = ""
    var letter: PrevisitLetterViewModel?
    var loadDays: (() async throws -> [PrevisitDay])?
    @State private var session: PrevisitSession
    @State private var records: PrevisitRecordState
    @State private var reloadID = 0
    /// 방금 보낸 기록 (완료 팝업·상세에 보여 줄 것)
    @State private var sentID: UUID?
    @State private var showsLetter = false
    @Environment(\.dismiss) private var dismiss

    init(doctorName: String = "선생님", patientName: String = "", session: PrevisitSession? = nil,
         letter: PrevisitLetterViewModel? = nil, loadDays: (() async throws -> [PrevisitDay])? = nil) {
        self.doctorName = doctorName
        self.patientName = patientName
        self.letter = letter
        self.loadDays = loadDays
        _session = State(initialValue: session ?? PrevisitSession())
        _records = State(initialValue: loadDays == nil ? .loaded([]) : .loading)
    }

    var body: some View {
        Group {
            if showsLetter, let letter, let sentID {
                PrevisitLetterView(viewModel: letter, id: sentID, patientName: patientName, onClose: { dismiss() })
            } else if let sentID, let sent = letter?.letter(sentID) {
                PrevisitPromptView(completedDraft: sent.draft, doctorName: doctorName, patientName: patientName,
                                   onStart: { showsLetter = true }, onClose: { dismiss() })
            } else {
                PrevisitRecordView(doctorName: doctorName, patientName: patientName, onClose: close, onSubmit: letter.map { letter in { draft in
                                       letter.send(draft, to: doctorName)
                                       session.discard()
                                       sentID = letter.latest?.id
                                   } }, session: session, records: records, onReload: { reloadID += 1 })
                    .task(id: reloadID) { await loadRecords() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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

#Preview("진료 전 기록 작성 · 실제 전송 안 됨") {
    NavigationStack { PrevisitFlowView() }
}
