import SwiftUI

/// 숫자로 해석할 수 없는 원문을 0이나 nil로 바꾸지 않고 오류로 남깁니다.
struct SymptomSummaryEntryEditor: View {
    let draft: SymptomEntryDisplay
    let onDelete: () -> Void
    let onFinish: (SymptomEntryEditInput) -> Void
    @State private var input: SymptomEntryEditInput
    var errorMessage: String?

    init(draft: SymptomEntryDisplay, errorMessage: String? = nil, onDelete: @escaping () -> Void,
         onFinish: @escaping (SymptomEntryEditInput) -> Void) {
        self.draft = draft; self.errorMessage = errorMessage
        self.onDelete = onDelete
        self.onFinish = onFinish
        _input = State(initialValue: SymptomEntryEditInput(draft))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(draft.symptomType.displayName)
                    .modifier(SymptomTextStyle(size: 16, weight: .semibold))
                Spacer()
                HStack(spacing: 40) {
                    Button("삭제", role: .destructive, action: onDelete).foregroundStyle(Color(red: 1, green: 33 / 255, blue: 33 / 255))
                    Button("완료", action: finish).foregroundStyle(Color(red: 33 / 255, green: 118 / 255, blue: 1))
                }
                .modifier(SymptomTextStyle(size: 16))
            }
            VStack(spacing: 0) {
                if draft.occurrenceCount != nil {
                    SymptomSummaryRow(title: "횟수") {
                        TextField("1~100회", text: $input.occurrenceText)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("횟수 수정")
                    }
                }
                if draft.durationMinutes != nil {
                    SymptomSummaryRow(title: "지속 시간 (분)") {
                        TextField("10~1440분", text: $input.durationText)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("지속 시간 수정")
                    }
                }
                if draft.severity != nil {
                    SymptomSummaryRow(title: "불편함 정도") {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 14) { severityControl; severityText }
                            VStack(alignment: .trailing) { severityText; severityControl }
                        }
                    }
                }
                if let location = draft.rawLocationText, !location.isEmpty {
                    SymptomSummaryRow(title: "부위") { Text(location).foregroundStyle(.secondary) }
                }
                if draft.detail != nil {
                    SymptomSummaryRow(title: "상세 내용") {
                        TextField("상세 내용", text: $input.detail, axis: .vertical)
                            .multilineTextAlignment(.trailing).accessibilityLabel("상세 내용 수정")
                    }
                }
            }
            .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 26))
            if let errorMessage {
                Text(errorMessage).font(.body).foregroundStyle(.red)
                    .accessibilityIdentifier("symptom.edit.error")
            }
        }
    }

    private var severityControl: some View {
        Slider(value: Binding(get: { input.severity ?? 0 }, set: { input.severity = $0 }), in: 0...10)
            .tint(Color(white: 102 / 255))
            .frame(minWidth: 80, maxWidth: 171)
            .accessibilityLabel("불편함 정도 수정")
            .accessibilityValue(severityValue)
    }

    private var severityText: some View {
        Text(severityValue).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private var severityValue: String {
        guard let value = input.severity else { return "입력하지 않음" }
        let text = value.rounded() == value ? String(Int(value)) : String(value)
        return "\(text)/10점"
    }

    private func finish() { onFinish(input) }
}
