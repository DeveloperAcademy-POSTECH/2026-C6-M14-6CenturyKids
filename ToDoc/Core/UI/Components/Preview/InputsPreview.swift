#if DEBUG
import SwiftUI

/// 입력·선택 동작을 확인하는 로컬 예시입니다. 실제 기록을 읽거나 저장하지 않습니다.
struct InputsPreview: View {
    var selectionOnly = false
    @State private var name = ""
    @State private var email = "잘못된 주소"
    @State private var memo = ""
    @State private var firstChip = true
    @State private var secondChip = false
    @State private var smallChip = false
    @State private var checked = false
    @State private var radio = "선택 A"
    @State private var period = "주"
    @State private var score = 5
    @State private var changes = 0
    @FocusState private var focus: Field?
    private enum Field: Hashable { case name, email, memo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preview 예시 · 실제 기록 아님")
                    .appTypography(.caption)
                    .foregroundStyle(AppColors.Semantic.Text.sub)
                if selectionOnly { selections } else { fields }
            }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
            .padding(.vertical, 24)
        }
        .background(AppColors.Semantic.Background.surface)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                SwiftUI.Button("입력 완료") { focus = nil }
            }
        }
        .navigationTitle(selectionOnly ? "Inputs · 선택" : "Inputs · 입력")
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 24) {
            AppInputs.TextField("이름", text: $name, placeholder: "이름을 입력하세요", helper: "한 줄 입력 예시")
                .focused($focus, equals: .name)
                .submitLabel(.done)
                .onSubmit { focus = nil }
            AppInputs.TextField("이메일", text: $email, placeholder: "이메일", error: "이메일 형식을 확인해 주세요")
                .focused($focus, equals: .email)
                .submitLabel(.done)
                .onSubmit { focus = nil }
            AppInputs.TextField("비활성 입력", text: .constant("수정할 수 없는 예시"), helper: "비활성 상태")
                .disabled(true)
            AppInputs.TextArea("메모", text: $memo, placeholder: "메모를 입력해 보세요")
                .focused($focus, equals: .memo)
            Text("입력 글자 수 · 이름 \(name.count) / 메모 \(memo.count)")
                .appTypography(.bodySmall)
                .foregroundStyle(AppColors.Semantic.Text.sub)
        }
    }

    private var selections: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: AppLayout.Phone.columnSpacing) {
                AppInputs.Chip("선택 A", isSelected: $firstChip)
                AppInputs.Chip("선택 B", isSelected: $secondChip)
            }
            AppInputs.Chip("작은 칩", size: .small, isSelected: $smallChip)
            Text("칩 선택 · A \(firstChip ? "켜짐" : "꺼짐") / B \(secondChip ? "켜짐" : "꺼짐") / 작은 칩 \(smallChip ? "켜짐" : "꺼짐")")
                .appTypography(.caption)
            HStack(spacing: 8) {
                AppInputs.Checkbox("예시 동의", isOn: $checked)
                Text("체크박스 · \(checked ? "선택됨" : "선택 안 됨")").appTypography(.body)
            }
            HStack(spacing: 12) {
                AppInputs.Radio("선택 A", value: "선택 A", selection: $radio)
                Text("A").appTypography(.body)
                AppInputs.Radio("선택 B", value: "선택 B", selection: $radio)
                Text("B · 현재 \(radio)").appTypography(.body)
            }
            AppInputs.SegmentedControl("보기 방식", options: ["월", "주", "일"], selection: $period, label: { $0 })
            AppInputs.WheelPicker("예시 점수", options: Array(1...10), selection: $score, unit: "점", label: { String($0) })
                .frame(width: 160)
                .frame(maxWidth: .infinity)
            Text("선택 변경 \(changes)회 · \(period) 보기 · 예시 점수 \(score)점")
                .appTypography(.bodySmall)
        }
        .foregroundStyle(AppColors.Semantic.Text.default)
        .onChange(of: firstChip) { changes += 1 }
        .onChange(of: secondChip) { changes += 1 }
        .onChange(of: smallChip) { changes += 1 }
        .onChange(of: checked) { changes += 1 }
        .onChange(of: radio) { changes += 1 }
        .onChange(of: period) { changes += 1 }
        .onChange(of: score) { changes += 1 }
    }
}

#Preview("Inputs · 입력") { NavigationStack { InputsPreview() } }
#Preview("Inputs · 선택") { NavigationStack { InputsPreview(selectionOnly: true) } }
#endif
