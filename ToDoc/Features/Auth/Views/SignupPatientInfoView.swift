import SwiftUI

struct SignupPatientInfoView: View {
    @Bindable var state: SignupScreenState
    @State private var showsBirthday = false
    @State private var selectedBirthday = Date()
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 16

    var body: some View {
        SignupStepScreen(state: state, title: "기본 정보를 입력해 주세요") {
            if state.hasStoredUserProfile {
                Text("이미 저장된 기본 정보를 불러왔어요. 이 가입 과정에서는 기존 정보를 변경하지 않아요.")
                    .appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
            }
            AuthTextField(title: "이름", placeholder: "이름을 입력해 주세요", text: $state.name, contentType: .name)
                .disabled(state.hasStoredUserProfile)
                .appTextLimit($state.name, maximum: 30, shakes: true)
            VStack(alignment: .leading, spacing: 10) {
                Text("생년월일").tracking(labelSize * 0.015).appTypography(.labelLarge)
                Button {
                    selectedBirthday = state.birthday ?? state.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? state.latestBirthday
                    showsBirthday = true
                } label: {
                    HStack {
                        Text(state.birthdayText ?? "생년월일 선택")
                            .tracking(labelSize * 0.015).appTypography(.labelLarge)
                            .foregroundStyle(state.birthday == nil ? AppColors.Semantic.Text.disabled
                                             : AppColors.Semantic.Text.default)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(AppColors.Semantic.Text.disabled)
                    }
                    .padding(16).frame(minHeight: 64)
                    .background(AppColors.Surface.control, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(AppActions.PressStyle()).disabled(state.hasStoredUserProfile)
                if let age = state.age {
                    Text("만 \(age)세 · 생년월일로 계산해요").appTypography(.bodySmall)
                        .foregroundStyle(AppColors.Semantic.Text.sub)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("성별").tracking(labelSize * 0.015).appTypography(.labelLarge)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { sexChoices }
                    VStack(spacing: 10) { sexChoices }
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
                        ToolbarItem(placement: .cancellationAction) {
                            Button("취소", systemImage: "xmark") { showsBirthday = false }
                                .labelStyle(.iconOnly)
                                .tint(AppColors.Semantic.Text.sub)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("확인", systemImage: "checkmark") {
                                state.birthday = selectedBirthday; showsBirthday = false
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.glassProminent)
                            .buttonBorderShape(.circle)
                            .tint(AppColors.Semantic.Primary.default)
                            .foregroundStyle(AppColors.Semantic.Text.inverse)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
    private var sexChoices: some View {
        Group {
            AuthChoice(title: "여성", isSelected: state.sex == .female, kind: .centered) { state.sex = .female }
            AuthChoice(title: "남성", isSelected: state.sex == .male, kind: .centered) { state.sex = .male }
        }
    }
}
