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
        VStack(spacing: AppSpacing.content) {
            HStack {
                Text(draft.symptomType.displayName)
                    .appFont(.bodyStrong)
                Spacer()
                HStack(spacing: AppSpacing.question) {
                    Button("삭제", role: .destructive, action: onDelete).foregroundStyle(AppColors.CareCall.deleteAction)
                    Button("완료", action: finish).foregroundStyle(AppColors.CareCall.doneAction)
                }
                .appFont(.body)
            }
            VStack(spacing: 0) {
                SymptomSummaryRow(title: "증상 유무") { Text(draft.presence.displayName).foregroundStyle(AppColors.CareCall.summarySecondary) }
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
                if let location = draft.rawLocationText, !location.isEmpty {
                    SymptomSummaryRow(title: "부위") { Text(location).foregroundStyle(AppColors.CareCall.summarySecondary) }
                }
                if draft.detail != nil {
                    SymptomSummaryRow(title: "상세 내용") {
                        TextField("상세 내용", text: $input.detail, axis: .vertical)
                            .multilineTextAlignment(.trailing).accessibilityLabel("상세 내용 수정")
                    }
                }
            }
            .appSurface(.conversationSummary)
            if let errorMessage {
                Text(errorMessage).font(AppTypography.NativeConversation.body).foregroundStyle(AppColors.Feedback.error)
                    .accessibilityIdentifier("symptom.edit.error")
            }
        }
    }

    private func finish() { onFinish(input) }
}
