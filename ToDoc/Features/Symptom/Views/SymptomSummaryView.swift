import SwiftUI

/// Figma 1:1870 / 1:1903. 저장 결과는 주입된 작업이 성공했을 때만 전달합니다.
struct SymptomSummaryView: View {
    @State private var state: SymptomSummaryScreenState
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)?

    init(state: SymptomSummaryScreenState, onBack: (() -> Void)? = nil) {
        _state = State(initialValue: state); self.onBack = onBack
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text("요약").modifier(SymptomTextStyle(size: 20, weight: .semibold))
                    Text("저장하기 전에 내용을 확인하고\n잘못된 부분은 수정해 주세요.")
                        .modifier(SymptomTextStyle(size: 15)).lineSpacing(6)
                        .foregroundStyle(Color(white: 101 / 255))
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                VStack(spacing: 24) {
                    ForEach(SymptomPresence.allCases, id: \.self) { presence in
                        let entries = state.record.entries(with: presence)
                        if !entries.isEmpty {
                            Text("\(presence.displayName)으로 답한 항목")
                                .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                        }
                        ForEach(entries) { entry in
                            if state.editingEntryID == entry.id {
                                SymptomSummaryEntryEditor(draft: entry, errorMessage: state.editErrorMessage,
                                    onDelete: { state.onAction?(.delete(entry.id)) },
                                    onFinish: { state.onAction?(.finishEdit(entry.id, $0)) })
                                .id(entry.id)
                            } else {
                                SymptomSummaryEntryView(entry: entry, canEdit: !state.isSaving &&
                                                        state.onAction != nil && state.editingEntryID == nil) {
                                    state.onAction?(.edit(entry.id))
                                }
                            }
                        }
                    }
                    if state.record.symptoms.isEmpty {
                        Text("기록된 답변이 없습니다.").font(.body).foregroundStyle(.secondary)
                    }
                }
                VStack(spacing: 16) {
                    if let error = state.errorMessage {
                        Text(error).font(.body).foregroundStyle(.red)
                            .accessibilityIdentifier("symptom.summary.error")
                    }
                    Button {
                        state.onAction?(.save)
                    } label: {
                        HStack {
                            Color.clear.frame(width: 12, height: 12)
                            Spacer(minLength: 8)
                            Text(state.isSaving ? "저장 중" : "저장하기")
                            Spacer(minLength: 8)
                            Image("CareConversationNext").frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(AppButtonStyle())
                    .disabled(!state.canSave || state.onAction == nil)
                    .accessibilityIdentifier("symptom.summary.save")
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.white)
        .overlay(alignment: .topLeading) {
            Button {
                state.onAction?(.discardEdit)
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image("CareSummaryBack").frame(width: 40, height: 38.23)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .accessibilityLabel("요약에서 돌아가기")
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { state.onAction?(.cancel) }
    }
}

private struct SymptomSummaryEntryView: View {
    let entry: SymptomEntryDisplay
    let canEdit: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(entry.symptomType.displayName)
                    .modifier(SymptomTextStyle(size: 16, weight: .semibold))
                Spacer()
                Button("수정", action: onEdit)
                    .modifier(SymptomTextStyle(size: 16))
                    .foregroundStyle(Color(white: 152 / 255))
                    .disabled(!canEdit)
                    .accessibilityLabel("\(entry.symptomType.displayName) 수정")
            }
            VStack(spacing: 0) {
                row("증상 유무", entry.presence.displayName)
                if let value = entry.occurrenceCount { row("횟수", "\(value)회") }
                if let value = entry.durationMinutes { row("지속 시간", "\(value)분") }
                if let value = entry.rawLocationText, !value.isEmpty { row("부위", value) }
                else if let part = entry.bodyPart {
                    row("부위", [entry.bodySide?.displayName, part.displayName].compactMap { $0 }.joined(separator: " "))
                }
                if let value = entry.detail, !value.isEmpty { row("상세 내용", value) }
                if entry.occurrenceCount == nil && entry.durationMinutes == nil &&
                    entry.rawLocationText?.isEmpty != false && entry.bodyPart == nil && entry.detail?.isEmpty != false {
                    row("추가 정보", "입력하지 않음")
                }
            }
            .background(Color(uiColor: .systemGray5), in: RoundedRectangle(cornerRadius: 26))
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        SymptomSummaryRow(title: title) {
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

struct SymptomSummaryRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                    content().frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 16) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    content()
                }
            }
        }
        .font(.body)
        .padding(.vertical, 16)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) { Divider() }
        .padding(.horizontal, 16)
    }
}
