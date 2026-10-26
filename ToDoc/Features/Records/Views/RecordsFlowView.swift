import SwiftUI

struct RecordsFlowView: View {
    @State var state = RecordsScreenState()
    @State private var path: [RecordOverviewKind] = []
    var pain: () -> PainRecordDetailView = { .init() }
    var symptom: () -> SymptomRecordDetailView = { .init() }
    var previsitLetter: PrevisitLetterViewModel?
    var onHome: () -> Void = {}
    @State private var showsPrevisitLetter = false
    var body: some View {
        NavigationStack(path: $path) {
            RecordsView(dateLabel: state.dateLabel, snapshot: state.snapshot, state: state.loadState,
                onMoveDay: state.onAction.map { action in { action(.moveDay($0)) } },
                onSelect: { state.onAction?(.select($0)); path.append($0) }, onRetry: state.onAction.map { action in { action(.load) } },
                previsitSubtitle: previsitLetter?.lastSentLabel,
                onSelectPrevisit: previsitLetter?.sent == nil ? nil : { showsPrevisitLetter = true })
                .onAppear { state.onAction?(.load) }.onDisappear { state.onAction?(.cancel) }
                .navigationDestination(for: RecordOverviewKind.self) { kind in
                    switch kind { case .pain: pain(); case .symptom: symptom() }
                }
                .navigationDestination(isPresented: $showsPrevisitLetter) {
                    if let previsitLetter {
                        PrevisitLetterView(viewModel: previsitLetter, onHome: { showsPrevisitLetter = false; onHome() })
                    }
                }
        }
    }
}
#Preview { RecordsFlowView() }
