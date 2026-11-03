import SwiftUI

/// View는 입력과 페이지 이동을 담당하고, ViewModel에서 기록을 저장합니다.
/// 먹기 전 통증을 먼저 저장하고, 1시간 뒤 같은 기록에 먹은 뒤 통증을 이어서 기록합니다.
struct PainRecordView: View {
    let viewModel: PainRecordViewModel
    private let analytics: AmplitudeAnalytics?
    private let entrySource: String?
    @State private var flowID = UUID()
    @State private var didTrackFlowEntry = false
    @State private var trackedTimerStates: Set<String> = []
    @State private var attempt: InputAttempt?
    @State private var state: PainScreenState
    @State private var stage = Stage.start
    @State private var savedRecord: PainRecord?
    @State private var showsSaveFailed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var onClose: (() -> Void)?
    var onShowRecord: ((PainRecord) -> Void)?
    var onHome: (() -> Void)?
    var onCancel: (() -> Void)?

    private struct InputAttempt {
        let id = UUID()
        var didSelectLocation = false
        var didConfirmScore = false
        var lastInteractedScore: Int?
    }

    private enum Stage {
        /// 기다리는 기록이 있으면 1시간 뒤 기록 타이머, 없으면 부위 선택.
        /// 타이머가 도는 동안 새로운 통증을 기록하면 부위 선택으로 가고, 저장하면 이전 기록은 먹기 전 점수만 남습니다.
        case start
        case location
        case before
        case after
    }

    init(viewModel: PainRecordViewModel, state: PainScreenState = PainScreenState(),
         analytics: AmplitudeAnalytics? = nil, entrySource: String? = nil,
         onClose: (() -> Void)? = nil, onShowRecord: ((PainRecord) -> Void)? = nil,
         onHome: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.analytics = analytics
        self.entrySource = entrySource
        _state = State(initialValue: state)
        self.onClose = onClose; self.onShowRecord = onShowRecord
        self.onHome = onHome; self.onCancel = onCancel
    }
    var body: some View {
        Group {
            switch viewModel.connectionState {
            case .ready:
                recordContent
            case .loading:
                ProgressView("통증 기록을 준비하고 있어요")
            case .signedOut:
                ContentUnavailableView("로그인이 필요해요", systemImage: "person.crop.circle",
                                       description: Text("통증 기록을 이용하려면 로그인해 주세요."))
            case .patientUnavailable:
                ContentUnavailableView("환자 계정을 찾지 못했어요", systemImage: "person.crop.circle.badge.questionmark")
            case .failed:
                ContentUnavailableView {
                    Label("통증 기록을 열 수 없어요", systemImage: "exclamationmark.circle")
                } description: {
                    Text("잠시 후 다시 시도해 주세요.")
                } actions: {
                    Button("다시 시도") {
                        Task { await load() }
                    }
                }
            }
        }
        .task {
            trackFlowEntryIfNeeded()
            await load()
        }
        .onDisappear { onCancel?() }
        .alert("기록을 저장하지 못했어요", isPresented: $showsSaveFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
    }

    private func load() async {
        await viewModel.load()
        guard !Task.isCancelled else { return }

        switch viewModel.connectionState {
        case .ready:
            stage = viewModel.pendingRecord == nil ? .location : .start
        case .patientUnavailable:
            trackPreparationFailure("patient_unavailable")
        case .failed:
            trackPreparationFailure("load_failed")
        case .loading, .signedOut:
            break
        }
    }

    private func trackPreparationFailure(_ errorCode: String) {
        trackPainEvent("pain_preparation_failed", properties: [
            "failure_step": "preparation",
            "error_code": errorCode
        ])
    }

    @ViewBuilder private var recordContent: some View {
        if let completion = state.completion {
            PainCompletionView(
                record: completion,
                onShowRecord: onShowRecord.map { destination in
                    { if let savedRecord { destination(savedRecord) } }
                },
                onHome: home
            )
        } else {
            switch stage {
            case .start:
                if let pending = viewModel.pendingRecord, let availableDate = viewModel.afterAvailableDate {
                    PainAfterTimerView(locations: pending.location, before: pending.painBefore,
                                       recordedDate: pending.recordedDate, availableDate: availableDate,
                                       remindersAllowed: viewModel.remindersAllowed,
                                       onLater: deferFollowup, onRecord: { stage = .after },
                                       onNewRecord: {
                                           viewModel.startNewRecord()
                                           attempt = nil
                                           stage = .location
                                       },
                                       onClose: close, onStateViewed: trackTimerState)
                        // 설정에서 알림을 켜고 돌아오면 안내를 지우고 알림을 다시 예약합니다
                        .task(id: scenePhase) {
                            if scenePhase == .active { await viewModel.refreshReminderPermission() }
                        }
                } else {
                    locationSelection
                }
            case .location:
                locationSelection
            case .before:
                PainBeforeMedicationView(locations: viewModel.selectedLocations, score: beforeScoreBinding,
                    isSaving: viewModel.isSaving, errorMessage: state.errorMessage,
                    onPrevious: returnToLocationSelection, onReselectLocations: returnToLocationSelection,
                    onNext: saveBefore, onClose: close,
                    onScoreInteractionEnded: { trackScoreInteractionEnded($0, phase: "before") })
                    .onAppear {
                        trackInputEvent("pain_step_moved", phase: "before", step: "score_input", properties: [
                            "from_step": "location_selection",
                            "to_step": "score_input",
                            "direction": "next"
                        ])
                    }
            case .after:
                if let pending = viewModel.pendingRecord {
                    PainAfterMedicationView(locations: pending.location, before: pending.painBefore,
                        score: afterScoreBinding, isSaving: viewModel.isSaving,
                        errorMessage: state.errorMessage,
                        onPrevious: returnToTimer, onNext: saveAfter, onClose: close,
                        onScoreInteractionEnded: { trackScoreInteractionEnded($0, phase: "after") })
                        .onAppear {
                            startAttemptIfNeeded(phase: "after", step: "score_input")
                        }
                }
            }
        }
    }

    private var locationSelection: some View {
        PainLocationSelectionView(locations: viewModel.selectedLocations, errorMessage: state.errorMessage,
            onToggle: toggleLocation,
            onRemove: { removeLocation($0, source: "selected_chip") },
            onRemoveFromSheet: { removeLocation($0, source: "location_sheet") },
            onRemoveAll: clearLocations,
            onNext: { stage = .before }, onClose: close)
            .onAppear {
                if trackedTimerStates.isEmpty, attempt == nil {
                    trackFlowEntryIfNeeded()
                    trackPainEvent("pain_entry_screen_viewed", properties: [
                        "screen": "location_selection"
                    ])
                }
                startAttemptIfNeeded(phase: "before", step: "location_selection")
            }
    }

    private var beforeScoreBinding: Binding<Int?> {
        Binding(
            get: { viewModel.painBefore },
            set: { score in
                if let score { viewModel.setBeforeScore(score) }
            }
        )
    }

    private var afterScoreBinding: Binding<Int?> {
        Binding(
            get: { viewModel.painAfter },
            set: { score in
                if let score { viewModel.setAfterScore(score) }
            }
        )
    }

    private func saveBefore() {
        guard !viewModel.isSaving, viewModel.painBefore != nil else { return }
        trackScoreConfirmed(phase: "before")

        Task { @MainActor in
            do {
                _ = try await viewModel.saveBeforeRecord()
                state.errorMessage = nil
                attempt = nil
                stage = .start
            } catch PainRecordViewModel.SaveError.alreadySaving {
                return
            } catch {
                showsSaveFailed = true
            }
        }
    }

    private func saveAfter() {
        guard !viewModel.isSaving, viewModel.painAfter != nil else { return }
        trackScoreConfirmed(phase: "after")

        Task { @MainActor in
            do {
                let record = try await viewModel.saveAfterRecord()
                savedRecord = record
                state.errorMessage = nil
                state.completion = PainCompletionData(
                    location: record.location,
                    painBefore: record.painBefore,
                    painAfter: record.painAfter,
                    painChange: record.painChange
                )
            } catch PainRecordViewModel.SaveError.alreadySaving {
                return
            } catch {
                showsSaveFailed = true
            }
        }
    }

    private func startAttemptIfNeeded(phase: String, step: String) {
        guard attempt == nil else { return }
        attempt = InputAttempt()
        trackInputEvent("pain_input_started", phase: phase, step: step)
    }

    private func toggleLocation(_ location: BodyLocation) {
        let previousCount = viewModel.selectedLocations.count
        viewModel.toggleLocation(location)
        let selectedCount = viewModel.selectedLocations.count
        guard selectedCount != previousCount else { return }

        trackLocationChange(action: selectedCount > previousCount ? "select" : "deselect",
                            source: "body_map")
        guard selectedCount > 0, attempt?.didSelectLocation == false else { return }

        attempt?.didSelectLocation = true
        trackInputEvent("pain_location_selected", phase: "before", step: "location_selection",
                        properties: ["selected_count": selectedCount])
    }

    private func removeLocation(_ location: BodyLocation, source: String) {
        let previousCount = viewModel.selectedLocations.count
        viewModel.removeLocation(location)
        guard viewModel.selectedLocations.count < previousCount else { return }

        trackLocationChange(action: "deselect", source: source)
    }

    private func clearLocations() {
        let removedCount = viewModel.selectedLocations.count
        guard removedCount > 0 else { return }

        viewModel.removeAllLocations()
        trackLocationChange(action: "clear_all", source: "location_sheet", removedCount: removedCount)
    }

    private func trackLocationChange(action: String, source: String, removedCount: Int? = nil) {
        var properties: [String: Any] = [
            "action": action,
            "source": source,
            "selected_count": viewModel.selectedLocations.count
        ]
        properties["removed_count"] = removedCount
        trackInputEvent("pain_location_changed", phase: "before", step: "location_selection",
                        properties: properties)
    }

    private func returnToLocationSelection() {
        stage = .location
        trackPreviousStep(phase: "before", destination: "location_selection")
    }

    private func returnToTimer() {
        stage = .start
        trackPreviousStep(phase: "after", destination: "timer")
    }

    private func trackPreviousStep(phase: String, destination: String) {
        trackInputEvent("pain_step_moved", phase: phase, step: destination, properties: [
            "from_step": "score_input",
            "to_step": destination,
            "direction": "previous"
        ])
    }

    private func trackScoreInteractionEnded(_ score: Int, phase: String) {
        guard let attempt else { return }

        let previousScore = attempt.lastInteractedScore
        self.attempt?.lastInteractedScore = score
        trackInputEvent("pain_score_interaction_ended", phase: phase, step: "score_input", properties: [
            "is_first_selection": previousScore == nil,
            "did_change": previousScore.map { $0 != score } ?? false
        ])
    }

    private func trackScoreConfirmed(phase: String) {
        guard attempt?.didConfirmScore == false else { return }

        attempt?.didConfirmScore = true
        trackInputEvent("pain_score_confirmed", phase: phase, step: "score_input")
    }

    private func trackInputEvent(_ name: String, phase: String, step: String,
                                 properties: [String: Any] = [:]) {
        guard let attempt else { return }

        var eventProperties = properties
        eventProperties["attempt_id"] = attempt.id.uuidString
        eventProperties["phase"] = phase
        eventProperties["step"] = step
        trackPainEvent(name, properties: eventProperties)
    }

    private func trackFlowEntryIfNeeded() {
        guard !didTrackFlowEntry else { return }

        didTrackFlowEntry = true
        var properties: [String: Any] = [:]
        properties["entry_source"] = entrySource
        trackPainEvent("pain_flow_entered", properties: properties)
    }

    private func trackTimerState(_ state: String) {
        trackFlowEntryIfNeeded()
        guard trackedTimerStates.insert(state).inserted else { return }

        trackPainEvent("pain_entry_screen_viewed", properties: [
            "screen": state == "waiting" ? "waiting" : "followup_choice",
            "timer_state": state
        ])
    }

    private func trackPainEvent(_ name: String, properties: [String: Any]) {
        var eventProperties = properties
        eventProperties["flow_id"] = flowID.uuidString
        analytics?.track(name, properties: eventProperties)
    }

    private func home() { if let onHome { onHome() } else { dismiss() } }
    private func close() {
        trackFlowClosed(reason: "back")
        if let onClose { onClose() } else { dismiss() }
    }

    private func deferFollowup() {
        trackFlowClosed(reason: "defer_followup")
        home()
    }

    private func trackFlowClosed(reason: String) {
        var properties: [String: Any] = ["exit_reason": reason]
        let step: String
        let phase: String?

        switch stage {
        case .start where viewModel.pendingRecord != nil && viewModel.afterAvailableDate != nil:
            step = "timer"
            phase = nil
        case .start, .location:
            step = "location_selection"
            phase = "before"
        case .before:
            step = "score_input"
            phase = "before"
        case .after:
            step = "score_input"
            phase = "after"
        }

        properties["step"] = step
        if let phase {
            properties["phase"] = phase
            properties["attempt_id"] = attempt?.id.uuidString
        }
        trackPainEvent("pain_flow_closed", properties: properties)
    }
}
#if DEBUG
private struct PreviewPainRepository: PainRepository {
    var latest: PainRecord?
    func findById(_ id: UUID) async throws -> PainRecord? { nil }
    func deleteById(_ id: UUID) async throws {}
    func save(entity: PainRecord) async throws {}
    func findByPatientId(_ patientId: UUID) async throws -> [PainRecord] { [] }
    func findByPatientIdAndDate(
        patientId: UUID,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [PainRecord] { [] }
    func findLatestByPatientId(_ patientId: UUID) async throws -> PainRecord? { latest }
    func savePainAfter(recordId: UUID, painAfter: Int) async throws {}
}

extension PainRecordView {
    @MainActor
    static func preview(state: PainScreenState = PainScreenState(), beforeSavedAgo: TimeInterval? = nil) -> Self {
        let patientId = UUID()
        let latest = beforeSavedAgo.flatMap {
            try? PainRecord(id: UUID(), patientId: patientId, recordedDate: .now.addingTimeInterval(-$0),
                            location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                            painBefore: 7, painAfter: nil)
        }
        return Self(
            viewModel: PainRecordViewModel(patientId: patientId, painRepository: PreviewPainRepository(latest: latest)),
            state: state
        )
    }
}

#Preview("입력 화면 · 저장 미연결") { PainRecordView.preview() }
#Preview("1시간 전 · 대기") { PainRecordView.preview(beforeSavedAgo: 20 * 60) }
#Preview("1시간 뒤 · 기록할 시간") { PainRecordView.preview(beforeSavedAgo: 90 * 60) }
#Preview("완료 화면 · 예시 결과") {
    let state = PainScreenState()
    state.completion = .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                             painBefore: 7, painAfter: 0, painChange: 7)
    return PainRecordView.preview(state: state)
}
#endif
