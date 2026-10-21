import SwiftUI

struct SignupPatientInfoView: View {
    @Bindable var state: SignupScreenState
    @State private var showsBirthday = false
    @State private var selectedBirthday = Date()

    var body: some View {
        SignupStepScreen(state: state, title: "기본 정보를\n알려주세요") {
            if state.hasStoredUserProfile {
                Text("이미 저장된 기본 정보를 불러왔어요. 이 가입 과정에서는 기존 정보를 변경하지 않아요.")
                    .appTextStyle(.caption)
            }
            AuthTextField(title: "이름", placeholder: "이름을 입력해 주세요", text: $state.name, contentType: .name)
                .disabled(state.hasStoredUserProfile)
            VStack(alignment: .leading, spacing: AppSpacing.Auth.fieldLabelGap) {
                Text("생년월일").appTextStyle(.label)
                Button {
                    selectedBirthday = state.birthday ?? state.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? state.latestBirthday
                    showsBirthday = true
                } label: {
                    HStack {
                        Text(state.birthdayText ?? "생년월일 선택")
                        Spacer()
                        Image(systemName: "calendar")
                    }
                    .appTextStyle(.label).padding(AppSpacing.Auth.informationPadding).frame(minHeight: AppMetrics.Auth.inputMinimumHeight)
                    .appSurface(.authInput)
                }.buttonStyle(.plain).disabled(state.hasStoredUserProfile)
                if let age = state.age {
                    Text("만 \(age)세 · 생년월일로 계산해요").appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                }
            }
            VStack(alignment: .leading, spacing: AppSpacing.Auth.fieldLabelGap) {
                Text("성별").appTextStyle(.label)
                ViewThatFits(in: .horizontal) {
                    HStack { sexChoices }
                    VStack { sexChoices }
                }.disabled(state.hasStoredUserProfile)
            }
        }
        .sheet(isPresented: $showsBirthday) {
            NavigationStack {
                DatePicker("생년월일", selection: $selectedBirthday, in: ...state.latestBirthday, displayedComponents: .date)
                    .datePickerStyle(.wheel).labelsHidden()
                    .environment(\.calendar, state.calendar)
                    .environment(\.timeZone, state.calendar.timeZone)
                    .environment(\.locale, state.locale)
                    .navigationTitle("생년월일").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("취소") { showsBirthday = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("확인") { state.birthday = selectedBirthday; showsBirthday = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
    private var sexChoices: some View {
        Group {
            AuthChoice(title: "여성", isSelected: state.sex == .female) { state.sex = .female }
            AuthChoice(title: "남성", isSelected: state.sex == .male) { state.sex = .male }
        }
    }
}
