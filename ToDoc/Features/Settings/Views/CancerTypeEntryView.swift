import SwiftUI

/// 입력과 화면 표시만 담당하며 저장은 외부 콜백으로 연결합니다.
struct CancerTypeEntryView: View {
    @Binding var name: String
    var isSaving = false
    var errorMessage: String?
    var onSubmit: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        !isSaving && onSubmit != nil && CarcinomaType(name: name) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsSection(title: "") {
                        SettingsInputRow(title: "암종") {
                            TextField("암종", text: $name)
                                .settingsText().multilineTextAlignment(.trailing)
                                .autocorrectionDisabled().textInputAutocapitalization(.never)
                                .focused($isFocused).submitLabel(.done)
                                .onSubmit { isFocused = false }
                                .disabled(isSaving).accessibilityIdentifier("settings.customCancerName")
                        }
                    }
                    if onSubmit == nil {
                        Text("저장 기능 연결 준비 중").settingsText(13).foregroundStyle(SettingsPalette.caption)
                    }
                    SettingsFeedback(busy: isSaving, error: errorMessage)
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SettingsPalette.background.ignoresSafeArea())
            .navigationTitle("암종 추가").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).tint(SettingsPalette.primary).disabled(isSaving)
                        .accessibilityIdentifier("settings.customCancer.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", systemImage: "checkmark") {
                        guard canSubmit else { return }
                        isFocused = false
                        onSubmit?(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    }.labelStyle(.iconOnly).buttonStyle(.borderedProminent)
                        .disabled(!canSubmit).accessibilityIdentifier("settings.customCancer.done")
                }
            }
            .tint(SettingsPalette.action)
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear { isFocused = true }
    }
}

#Preview("암종 추가 · 저장 미연결") {
    CancerTypeEntryView(name: .constant(""))
}
