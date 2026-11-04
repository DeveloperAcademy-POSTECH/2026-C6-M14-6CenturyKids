import SwiftUI

struct PersonalInfoEditView: View {
    @State private var state: PersonalInfoScreenState?
    @State private var showsBirthday = false
    @State private var nameLimitHits = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    var onWithdrawal: (() -> Void)?
    private let onSaved: () -> Void
    init(state: PersonalInfoScreenState? = nil, onSaved: @escaping () -> Void = {}) {
        _state = State(initialValue: state); self.onSaved = onSaved
    }
    var body: some View {
        SettingsScreen(title: "내 정보 수정", cancelTitle: "취소", canSave: state?.canSave == true && state?.onSave != nil,
                       isSaving: state?.isSaving == true, fillsAvailableHeight: true, save: save, cancel: { dismiss() }) {
            if let state {
                SettingsSection(title: "개인 정보", footer: "변경한 정보는 완료를 누르면 저장돼요.") {
                    SettingsInputRow(title: "이름") {
                        TextField("이름", text: Binding(get: { state.name }, set: { state.name = $0 }))
                            .settingsText().multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing).foregroundStyle(SettingsPalette.secondary)
                            .textContentType(.name).submitLabel(.done).autocorrectionDisabled()
                            .disabled(state.isSaving).accessibilityIdentifier("settings.name")
                            // 30자를 넘게 치면 잘라 내고 입력칸을 흔들어 알려 줍니다.
                            .onChange(of: state.name) { _, name in
                                guard name.count > 30 else { return }
                                state.name = String(name.prefix(30))
                                nameLimitHits += 1
                            }
                            .keyframeAnimator(initialValue: 0.0, trigger: nameLimitHits) { content, x in
                                content.offset(x: reduceMotion ? 0 : x)
                            } keyframes: { _ in
                                KeyframeTrack {
                                    for x in [8.0, -8, 6, -6, 3, 0] { LinearKeyframe(x, duration: 0.05) }
                                }
                            }
                            .sensoryFeedback(.error, trigger: nameLimitHits)
                    }
                    SettingsDivider()
                    Button { showsBirthday = true } label: {
                        SettingsRow(title: "생년월일", value: birthdayText(state))
                    }.disabled(state.isSaving).accessibilityIdentifier("settings.birthday")
                    SettingsDivider()
                    Menu {
                        ForEach(Sex.allCases, id: \.rawValue) { sex in
                            Button(sex.displayName) { state.sex = sex }
                        }
                    } label: { SettingsRow(title: "성별", value: state.sex.displayName, chevron: true) }
                        .disabled(state.isSaving).accessibilityIdentifier("settings.sex")
                }
                SettingsFeedback(error: state.validationMessage ?? state.errorMessage)
            } else { Text("개인정보를 먼저 불러와 주세요.").settingsText() }
            Spacer(minLength: 0)
            Button { onWithdrawal?() } label: {
                Text("회원 탈퇴").foregroundStyle(.red)
            }
                .buttonStyle(.glass)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(state?.isSaving == true || onWithdrawal == nil)
                .accessibilityIdentifier("settings.withdrawal")
        }
        .tint(SettingsPalette.action)
        .sheet(isPresented: $showsBirthday) {
            if let state {
                NavigationStack {
                    DatePicker("생년월일", selection: Binding(get: { state.birthday }, set: { state.birthday = $0 }),
                               in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).padding().environment(\.calendar, state.calendar)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("선택 완료") { showsBirthday = false } } }
                        .navigationTitle("생년월일").navigationBarTitleDisplayMode(.inline)
                }.presentationDetents([.medium, .large])
            }
        }
        .onAppear { state?.onLoad?() }
        .onDisappear { state?.onCancel?() }
        .onChange(of: state?.didSave) { _, saved in if saved == true { onSaved(); dismiss() } }
    }
    private func birthdayText(_ state: PersonalInfoScreenState) -> String {
        let c = state.calendar.dateComponents([.year, .month, .day], from: state.birthday)
        return String(format: "%04d.%02d.%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    private func save() { state?.onSave?() }
}
#Preview("미연결") { NavigationStack { PersonalInfoEditView() } }
