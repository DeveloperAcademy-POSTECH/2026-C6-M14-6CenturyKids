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
            VStack(spacing: AppSpacing.question) {
                VStack(spacing: AppSpacing.item) {
                    Text("요약").appFont(.sectionTitle)
                    Text("저장하기 전에 내용을 확인하고\n잘못된 부분은 수정해 주세요.")
                        .appFont(.bodySmall).lineSpacing(6)
                        .foregroundStyle(AppColors.Text.control)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                VStack(spacing: AppSpacing.section) {
                    ForEach(state.record.presentSymptoms) { entry in
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
                    if state.record.presentSymptoms.isEmpty {
                        Text("표시할 증상 기록이 없어요.").font(AppTypography.NativeConversation.body).foregroundStyle(AppColors.CareCall.summarySecondary)
                    }
                }
                VStack(spacing: AppSpacing.content) {
                    if let error = state.errorMessage {
                        Text(error).font(AppTypography.NativeConversation.body).foregroundStyle(AppColors.Feedback.error)
                            .accessibilityIdentifier("symptom.summary.error")
                    }
                    Button {
                        state.onAction?(.save)
                    } label: {
                        AppForwardLabel(title: state.isSaving ? "저장 중" : "저장하기", asset: "CareConversationNext")
                    }
                    .buttonStyle(AppButtonStyle())
                    .disabled(!state.canSave || state.onAction == nil)
                    .accessibilityIdentifier("symptom.summary.save")
                }
                .padding(.top, AppSpacing.columnGap)
            }
            .padding(.horizontal, 20)
            .padding(.top, AppSpacing.question)
            .padding(.bottom, 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.surface)
        .overlay(alignment: .topLeading) {
            Button {
                state.onAction?(.discardEdit)
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image("CareSummaryBack").frame(width: 40, height: 38.23)
                    .frame(width: AppMetrics.Control.minimumHitSize, height: AppMetrics.Control.minimumHitSize)
                    .contentShape(Rectangle()).offset(x: -2, y: -2.885)
            }
            .buttonStyle(.plain)
            .padding(.leading, AppSpacing.section)
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
        VStack(spacing: AppSpacing.content) {
            HStack {
                Text(entry.symptomType.displayName)
                    .appFont(.bodyStrong)
                Spacer()
                Button("수정", action: onEdit)
                    .appFont(.body)
                    .foregroundStyle(AppColors.CareCall.editAction)
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
            .appSurface(.conversationSummary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        SymptomSummaryRow(title: title) {
            Text(value).foregroundStyle(AppColors.CareCall.summarySecondary).multilineTextAlignment(.trailing)
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
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    Text(title)
                    content().frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: AppSpacing.content) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    content()
                }
            }
        }
        .font(AppTypography.NativeConversation.body)
        .padding(.vertical, AppSpacing.content)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) { Divider() }
        .padding(.horizontal, 16)
    }
}
