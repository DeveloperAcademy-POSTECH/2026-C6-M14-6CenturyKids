import SwiftUI

struct SignupPatientInfoView: View {
    @Bindable var model: SignupViewModel
    @State private var showsBirthday = false
    @State private var selectedBirthday = Date()

    var body: some View {
        SignupStepScreen(model: model, title: "기본 정보를\n알려주세요") {
            AuthTextField(title: "이름", placeholder: "이름을 입력해 주세요", text: $model.name, contentType: .name)
            VStack(alignment: .leading, spacing: 10) {
                Text("생년월일").appTextStyle(.label)
                Button {
                    selectedBirthday = model.birthday ?? model.calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? model.latestBirthday
                    showsBirthday = true
                } label: {
                    HStack {
                        Text(model.birthdayText ?? "생년월일 선택")
                        Spacer()
                        Image(systemName: "calendar")
                    }
                    .appTextStyle(.label).padding(20).frame(minHeight: 60)
                    .background(AppColors.secondary, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                if let age = model.age {
                    Text("만 \(age)세 · 생년월일로 계산해요").appTextStyle(.caption)
                        .foregroundStyle(AppColors.Text.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("성별").appTextStyle(.label)
                ViewThatFits(in: .horizontal) {
                    HStack { sexChoices }
                    VStack { sexChoices }
                }
            }
        }
        .sheet(isPresented: $showsBirthday) {
            NavigationStack {
                DatePicker("생년월일", selection: $selectedBirthday, in: ...model.latestBirthday, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .environment(\.calendar, model.calendar)
                    .environment(\.timeZone, model.calendar.timeZone)
                    .navigationTitle("생년월일").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("취소") { showsBirthday = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("확인") { model.birthday = selectedBirthday; showsBirthday = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
    private var sexChoices: some View {
        Group {
            AuthChoice(title: "여성", isSelected: model.sex == .female) { model.sex = .female }
            AuthChoice(title: "남성", isSelected: model.sex == .male) { model.sex = .male }
        }
    }
}
