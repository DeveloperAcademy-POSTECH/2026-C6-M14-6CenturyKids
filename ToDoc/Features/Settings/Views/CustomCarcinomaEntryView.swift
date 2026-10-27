import SwiftUI

struct CustomCarcinomaEntryView: View {
    let state: DiagnosisScreenState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSection(title: "") {
                        SettingsInputRow(title: "암종") {
                            TextField("암종", text: Binding(
                                get: { state.customCancerName },
                                set: { state.customCancerName = $0 }
                            ))
                            .settingsText()
                            .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isNameFocused)
                            .disabled(state.isSaving)
                            .accessibilityIdentifier("settings.carcinoma.customName")
                        }
                    }
                    SettingsFeedback(error: state.errorMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(SettingsPalette.primary)
        .background(SettingsPalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .buttonStyle(.plain)
        .onAppear { isNameFocused = true }
        .onChange(of: state.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(state.isSaving)
            .accessibilityLabel("취소")
            .accessibilityIdentifier("settings.carcinoma.customCancel")

            Spacer(minLength: 0)
            Text("암종 추가")
                .settingsText(17, bold: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)

            Button { state.onSaveCustomCancer?() } label: {
                Group {
                    if state.isSaving {
                        ProgressView().accessibilityLabel("저장 중")
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!state.canSaveCustomCancer || state.onSaveCustomCancer == nil)
            .accessibilityLabel("암종 저장")
            .accessibilityIdentifier("settings.carcinoma.customSave")
        }
        .foregroundStyle(SettingsPalette.primary)
    }
}

#Preview("암종 추가") {
    let state = DiagnosisScreenState()
    state.onSaveCustomCancer = {}
    return CustomCarcinomaEntryView(state: state)
}

#Preview("저장 실패") {
    let state = DiagnosisScreenState()
    state.customCancerName = "희귀암"
    state.errorMessage = "암종을 저장하지 못했어요. 다시 시도해 주세요."
    state.onSaveCustomCancer = {}
    return CustomCarcinomaEntryView(state: state)
}
