import SwiftUI

struct DiagnosisEditScreen: View {
    @State private var state: DiagnosisScreenState?
    @Environment(\.dismiss) private var dismiss
    let field: DiagnosisField
    private let onSaved: () -> Void
    init(state: DiagnosisScreenState?, field: DiagnosisField, onSaved: @escaping () -> Void) {
        _state = State(initialValue: state); self.field = field; self.onSaved = onSaved
    }
    var body: some View {
        SettingsScreen(title: field == .carcinoma ? "암종" : "병기", canSave: state?.canSave == true && state?.onSave != nil,
                       isSaving: state?.isSaving == true, save: save, cancel: { dismiss() }) {
            if let state {
                if field == .carcinoma {
                    cancerSection("호흡기 및 흉부", values: [.lung, .larynx, .thymus], state: state)
                    cancerSection("소화기계", values: [.stomach, .colorectal, .liver, .pancreas, .gallbladderAndBileDuct, .esophagus, .smallIntestine, .anus], state: state)
                    // 기존 가입 계약의 나머지 암종은 원본에 그룹이 없어 기본 목록으로 보존합니다.
                    cancerSection("그 외 암종", values: [.thyroid, .kidney, .breast, .prostate], state: state)
                    Text("진단받은 내용을 기준으로 선택해 주세요.").settingsText(13).foregroundStyle(SettingsPalette.caption).padding(.horizontal, 16)
                } else {
                    SettingsSection(title: "진단받은 병기", footer: "진단받은 병기를 선택해 주세요.\n정확한 병기는 담당 의료진에게 확인할 수 있어요.") {
                        ForEach(Array(CarcinomaStage.allCases.enumerated()), id: \.element.rawValue) { index, stage in
                            if index > 0 { SettingsDivider() }
                            choice(.stage(stage), title: stage.displayName, state: state)
                        }
                    }
                }
                SettingsFeedback(error: state.errorMessage)
            } else { Text("환자 정보를 먼저 불러와 주세요.").settingsText() }
        }.onDisappear { state?.onCancel?() }
        .onChange(of: state?.didSave) { _, saved in if saved == true { onSaved(); dismiss() } }
    }
    private func cancerSection(_ title: String, values: [CarcinomaType], state: DiagnosisScreenState) -> some View {
        SettingsSection(title: title) {
            ForEach(Array(values.enumerated()), id: \.element.rawValue) { index, value in
                if index > 0 { SettingsDivider() }
                choice(.carcinoma(value), title: displayName(value), subtitle: value == .lung ? "비소세포폐암 · 소세포폐암" : nil, state: state)
            }
        }
    }
    private func displayName(_ cancer: CarcinomaType) -> String {
        switch cancer {
        case .colorectal: "대장암 (결장암·직장암)"
        case .gallbladderAndBileDuct: "담도·담낭암"
        default: cancer.displayName
        }
    }
    private func choice(_ value: DiagnosisChange, title: String, subtitle: String? = nil, state: DiagnosisScreenState) -> some View {
        let selected = state.selection == value
        return Button { state.selection = value } label: {
            SettingsRow(title: title, subtitle: subtitle, selected: selected)
        }.disabled(state.isSaving).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("settings.choice.\(identifier(value))")
    }
    private func identifier(_ value: DiagnosisChange) -> String {
        switch value { case .carcinoma(let cancer): cancer.rawValue; case .stage(let stage): stage.rawValue }
    }
    private func save() { state?.onSave?() }
}
