import SwiftUI

struct DiagnosisEditScreen: View {
    @State private var state: DiagnosisScreenState?
    @State private var showsCustomCancerEntry = false
    @State private var isCustomCancerFlow = false
    @Environment(\.dismiss) private var dismiss
    let field: DiagnosisField
    private let onSaved: () -> Void
    private let onAddCancer: (() -> Void)?
    init(state: DiagnosisScreenState?, field: DiagnosisField, onSaved: @escaping () -> Void,
         onAddCancer: (() -> Void)? = nil) {
        _state = State(initialValue: state); self.field = field; self.onSaved = onSaved
        self.onAddCancer = onAddCancer
    }
    var body: some View {
        SettingsScreen(title: field == .carcinoma ? "암종" : "병기", canSave: state?.canSave == true && state?.onSave != nil,
                       isSaving: state?.isSaving == true, save: save, cancel: { dismiss() }) {
            if let state {
                if field == .carcinoma {
                    cancerSection(state: state)
                    SettingsSection(title: "기타") {
                        Button {
                            state.onBeginCustomCancer?()
                            isCustomCancerFlow = true
                            showsCustomCancerEntry = true
                        } label: {
                            SettingsRow(title: "암종 추가", chevron: true)
                        }
                        .disabled(!state.canSave || state.isSaving || state.onBeginCustomCancer == nil)
                        .accessibilityIdentifier("settings.carcinoma.custom")
                    }
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
        }
        .fullScreenCover(isPresented: $showsCustomCancerEntry, onDismiss: finishCustomCancerEntry) {
            if let state {
                CustomCarcinomaEntryView(state: state)
            }
        }
        .onAppear { if !isCustomCancerFlow { state?.onLoad?() } }
        .onDisappear { if !isCustomCancerFlow { state?.onCancel?() } }
        .onChange(of: state?.didSave) { _, saved in
            if saved == true && !isCustomCancerFlow { onSaved(); dismiss() }
        }
    }
    private func cancerSection(state: DiagnosisScreenState) -> some View {
        var values = CarcinomaType.allCases
        if case .carcinoma(let selected)? = state.selection, !values.contains(selected) { values.append(selected) }
        return SettingsSection(title: "") {
            ForEach(Array(values.enumerated()), id: \.element.rawValue) { index, value in
                if index > 0 { SettingsDivider() }
                choice(.carcinoma(value), title: value.displayName, state: state)
            }
        }
    }
    private func choice(_ value: DiagnosisChange, title: String, subtitle: String? = nil, state: DiagnosisScreenState) -> some View {
        let selected = state.selection == value
        return Button { state.selection = value } label: {
            if field == .carcinoma {
                HStack(spacing: 12) {
                    ZStack {
                        if selected {
                            Circle().fill(SettingsPalette.action)
                            Image("SettingsCheck").resizable().renderingMode(.template)
                                .foregroundStyle(.white).frame(width: 11, height: 9)
                        } else { Circle().strokeBorder(SettingsPalette.secondary.opacity(0.4), lineWidth: 1.5) }
                    }.frame(width: 20, height: 20).accessibilityHidden(true)
                    Text(title).settingsText().fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 52)
                    .contentShape(Rectangle())
            } else { SettingsRow(title: title, subtitle: subtitle, selected: selected) }
        }.disabled(state.isSaving).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("settings.choice.\(identifier(value))")
    }
    private func identifier(_ value: DiagnosisChange) -> String {
        switch value { case .carcinoma(let cancer): cancer.rawValue; case .stage(let stage): stage.rawValue }
    }
    private func save() { state?.onSave?() }
    private func finishCustomCancerEntry() {
        if state?.didSave == true {
            onSaved()
            dismiss()
        } else {
            state?.onCancelCustomCancer?()
            isCustomCancerFlow = false
        }
    }
}
