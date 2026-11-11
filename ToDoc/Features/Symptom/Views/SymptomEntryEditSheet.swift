import SwiftUI

/// Figma 447:10886 증상 수정 시트: 닫기(X)·증상 이름·완료(✓), 횟수 −/+, 지속 시간 휠, 상세 내용.
/// 값 검증은 ViewModel(SymptomRecord.editingEntry)이 하고, 걸리면 errorMessage로 이유를 보여 줍니다.
/// 지우기는 '없음 + 검토 필요'로 남기는 기존 규칙 그대로입니다.
struct SymptomEntryEditSheet: View {
    let draft: SymptomEntryDisplay
    var errorMessage: String?
    let onClose: () -> Void
    let onDelete: () -> Void
    let onFinish: (SymptomEntryEditInput) -> Void
    @State private var count: Int
    @State private var minutes: Int
    @State private var detail: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(draft: SymptomEntryDisplay, errorMessage: String? = nil, onClose: @escaping () -> Void,
         onDelete: @escaping () -> Void, onFinish: @escaping (SymptomEntryEditInput) -> Void) {
        self.draft = draft; self.errorMessage = errorMessage
        self.onClose = onClose; self.onDelete = onDelete; self.onFinish = onFinish
        _count = State(initialValue: draft.occurrenceCount ?? 1)
        _minutes = State(initialValue: draft.durationMinutes ?? 10)
        _detail = State(initialValue: draft.detail ?? "")
    }

    private var hours: Int { minutes / 60 }
    private var usesLargeLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    private var minuteValues: [Int] {
        if hours == 24 { return [0] }
        var values = Array(stride(from: 0, through: 55, by: 5))
        if !values.contains(minutes % 60) { values.append(minutes % 60) }
        return values.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    if usesLargeLayout { symptomTitle }
                    if draft.occurrenceCount != nil { countCard }
                    if draft.durationMinutes != nil { durationCard }
                    detailCard
                    if let errorMessage {
                        Text(errorMessage).font(.body).foregroundStyle(.red)
                            .accessibilityIdentifier("symptom.edit.error")
                    }
                    Button("삭제하기", role: .destructive, action: onDelete)
                        .modifier(SymptomTextStyle(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 1, green: 33 / 255, blue: 33 / 255))
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, usesLargeLayout ? 16 : 30)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(white: 248 / 255))
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(errorMessage != nil)
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image("CareGrayCircle").frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(white: 101 / 255))
                    }
            }
            .accessibilityLabel("닫기")
            Spacer()
            if !usesLargeLayout {
                symptomTitle
                Spacer()
            }
            Button(action: finish) {
                Image("CareGreenCircle").frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "checkmark").font(.system(size: 20, weight: .regular)).foregroundStyle(.white)
                    }
            }
            .accessibilityLabel("완료")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var symptomTitle: some View {
        Text(draft.symptomType.displayName)
            .modifier(SymptomTextStyle(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var fieldLayout: AnyLayout {
        usesLargeLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
    }

    private var countCard: some View {
        fieldLayout {
            Text("횟수").modifier(SymptomTextStyle(size: 16, weight: .semibold))
            if !usesLargeLayout { Spacer() }
            HStack(spacing: usesLargeLayout ? 0 : nil) {
                HStack(spacing: 0) {
                    stepButton("minus", label: "횟수 줄이기", enabled: count > 1) { count -= 1 }
                    Text("\(count)").modifier(SymptomTextStyle(size: 16, weight: .medium))
                        .monospacedDigit().fixedSize().frame(minWidth: 30)
                    stepButton("plus", label: "횟수 늘리기", enabled: count < 100) { count += 1 }
                }
                .padding(.horizontal, 4)
                .background(Color(white: 244 / 255), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("횟수")
                .accessibilityValue("\(count)회")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: count = min(100, count + 1)
                    case .decrement: count = max(1, count - 1)
                    @unknown default: break
                    }
                }
                Text("회").modifier(SymptomTextStyle(size: 16, weight: .medium)).padding(.leading, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .regular))
                .frame(width: usesLargeLayout ? 44 : 30, height: usesLargeLayout ? 44 : 35)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color(white: 101 / 255) : Color(white: 210 / 255))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var durationCard: some View {
        VStack(spacing: 8) {
            fieldLayout {
                Text("지속 시간").modifier(SymptomTextStyle(size: 16, weight: .semibold))
                if !usesLargeLayout { Spacer() }
                Text(symptomDurationText(minutes)).modifier(SymptomTextStyle(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            durationPickers
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
    }

    @ViewBuilder
    private var durationPickers: some View {
        let selectedHours = Binding(get: { hours }, set: { minutes = $0 * 60 + ($0 == 24 ? 0 : minutes % 60) })
        let selectedMinutes = Binding(get: { minutes % 60 }, set: { minutes = hours * 60 + $0 })
        if usesLargeLayout {
            AppInputs.WheelPicker("시간", options: Array(0...24), selection: selectedHours) { "\($0)시간" }
            AppInputs.WheelPicker("분", options: minuteValues, selection: selectedMinutes) { "\($0)분" }
        } else {
            HStack(spacing: 0) {
                Picker("시간", selection: selectedHours) {
                    ForEach(0...24, id: \.self) { Text("\($0)").tag($0) }
                }
                Text("hr").modifier(SymptomTextStyle(size: 14))
                Picker("분", selection: selectedMinutes) {
                    ForEach(minuteValues, id: \.self) { Text("\($0)").tag($0) }
                }
                Text("m").modifier(SymptomTextStyle(size: 14))
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("상세 내용").modifier(SymptomTextStyle(size: 16, weight: .semibold))
            TextField("내용을 입력해 주세요", text: $detail, axis: .vertical)
                .modifier(SymptomTextStyle(size: 14)).tracking(-0.14).lineSpacing(3)
                .foregroundStyle(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255))
                .lineLimit(usesLargeLayout ? 2...6 : 8...14)
                .accessibilityLabel("상세 내용 수정")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 30))
    }

    /// 원래 값이 없던 칸은 비워서 넘긴다 (값을 새로 만들지 않는다)
    private func finish() {
        var input = SymptomEntryEditInput(draft)
        if draft.occurrenceCount != nil { input.occurrenceText = String(count) }
        if draft.durationMinutes != nil { input.durationText = String(minutes) }
        input.detail = detail
        onFinish(input)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SymptomEntryEditSheet(draft: SymptomEntryDisplay(id: UUID(), symptomType: .diarrhea, presence: .present,
                                                         durationMinutes: 210, occurrenceCount: 10, detail: "오늘 설사를 세 번 했어요."),
                              onClose: {}, onDelete: {}, onFinish: { _ in })
    }
}
