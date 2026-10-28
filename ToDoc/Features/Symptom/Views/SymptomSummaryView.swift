import SwiftUI

/// Figma 447:10860 / 447:10813 요약. 저장 결과는 주입된 작업이 성공했을 때만 전달합니다.
/// 증상 카드를 누르면 수정 시트(447:10886)가 열립니다.
struct SymptomSummaryView: View {
    @State private var state: SymptomSummaryScreenState
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)?

    init(state: SymptomSummaryScreenState, onBack: (() -> Void)? = nil) {
        _state = State(initialValue: state); self.onBack = onBack
    }

    private var canEdit: Bool { !state.isSaving && state.onAction != nil && state.editingEntryID == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("오늘의 이야기").modifier(SymptomTextStyle(size: 20, weight: .bold)).tracking(-0.2)
                        .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottom)
                        .accessibilityAddTraits(.isHeader)
                    Text("내용 확인 후 수정할 내용이 있다면 카드를 눌러 주세요.")
                        .modifier(SymptomTextStyle(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 114 / 255))
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
                VStack(spacing: 20) {
                    ForEach(state.record.presentSymptoms) { entry in
                        SymptomSummaryCard(entry: entry, canEdit: canEdit) { state.onAction?(.edit(entry.id)) }
                    }
                    if state.record.presentSymptoms.isEmpty {
                        Text("표시할 증상 기록이 없어요.").font(.body).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 24) {
                if let error = state.errorMessage {
                    Text(error).font(.body).foregroundStyle(.red)
                        .accessibilityIdentifier("symptom.summary.error")
                }
                if !state.record.presentSymptoms.isEmpty {
                    Text("눌러서 수정할 수 있어요").modifier(SymptomTextStyle(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 114 / 255))
                }
                Button {
                    state.onAction?(.save)
                } label: {
                    AppForwardLabel(title: state.isSaving ? "저장 중" : "오늘 이야기 저장하기", asset: "CareConversationNext")
                }
                .buttonStyle(AppButtonStyle())
                .disabled(!state.canSave || state.onAction == nil)
                .accessibilityIdentifier("symptom.summary.save")
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 2)
            // Figma: 위쪽만 살짝 흐려지는 흰 바탕 (아래 카드가 비친다)
            .background(LinearGradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white, location: 0.106)],
                                       startPoint: .top, endPoint: .bottom))
        }
        .background(.white)
        .overlay(alignment: .topLeading) {
            Button {
                state.onAction?(.discardEdit)
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image("CareGrayCircle").frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color(white: 101 / 255))
                    }
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .padding(.top, 11)
            .accessibilityLabel("요약에서 돌아가기")
        }
        .sheet(isPresented: Binding(get: { editingEntry != nil }, set: { if !$0 { state.onAction?(.discardEdit) } })) {
            if let entry = editingEntry {
                SymptomEntryEditSheet(draft: entry, errorMessage: state.editErrorMessage,
                                      onClose: { state.onAction?(.discardEdit) },
                                      onDelete: { state.onAction?(.delete(entry.id)) },
                                      onFinish: { state.onAction?(.finishEdit(entry.id, $0)) })
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { state.onAction?(.cancel) }
    }

    private var editingEntry: SymptomEntryDisplay? {
        state.editingEntryID.flatMap { id in state.record.symptoms.first { $0.id == id } }
    }
}

/// Figma 447:10860 증상 카드: 이름(부위)과 횟수·지속 시간, 그 아래 상세 내용. 5줄이 넘으면 접어 두고 ⌄로 펼친다
private struct SymptomSummaryCard: View {
    let entry: SymptomEntryDisplay
    let canEdit: Bool
    let onEdit: () -> Void
    @State private var isExpanded = false

    private static let text = Color(red: 43 / 255, green: 40 / 255, blue: 43 / 255)
    // ponytail: 글자 수로 5줄 넘는 글을 가린다. 정확히 필요하면 텍스트 높이를 재서 바꾼다
    private var isLong: Bool { (entry.detail?.count ?? 0) > 110 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title).modifier(SymptomTextStyle(size: 16, weight: .semibold)).tracking(0.24)
                    .foregroundStyle(Self.text)
                Spacer(minLength: 8)
                if let value {
                    HStack(spacing: 2) {
                        Image("CareSummaryDot").frame(width: 24, height: 24).accessibilityHidden(true)
                        Text(value).modifier(SymptomTextStyle(size: 14, weight: .medium)).tracking(-0.14)
                            .foregroundStyle(Self.text)
                    }
                }
            }
            if let detail = entry.detail, !detail.isEmpty {
                Text(detail).modifier(SymptomTextStyle(size: 14)).tracking(-0.14)
                    .foregroundStyle(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255))
                    .lineSpacing(3)
                    .lineLimit(isLong && !isExpanded ? 5 : nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isLong {
                    Button { isExpanded.toggle() } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 16))
                            .foregroundStyle(Color(white: 131 / 255))
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "내용 접기" : "내용 펼치기")
                }
            } else if value == nil {
                Text("입력한 내용이 없어요").modifier(SymptomTextStyle(size: 14))
                    .foregroundStyle(Color(white: 152 / 255))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, isLong ? 8 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 248 / 255), in: RoundedRectangle(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture { if canEdit { onEdit() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(canEdit ? "두 번 탭해 수정" : "")
        .accessibilityAction { if canEdit { onEdit() } }
    }

    private var title: String {
        let location = entry.rawLocationText.flatMap { $0.isEmpty ? nil : $0 }
            ?? entry.bodyPart.map { part in [entry.bodySide?.displayName, part.displayName].compactMap { $0 }.joined(separator: " ") }
        return location.map { "\(entry.symptomType.displayName) (\($0))" } ?? entry.symptomType.displayName
    }

    private var value: String? {
        let parts = [entry.occurrenceCount.map { "\($0)회" }, entry.durationMinutes.map(symptomDurationText)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 분 → "1시간 30분" / "24시간" / "30분"
func symptomDurationText(_ minutes: Int) -> String {
    switch (minutes / 60, minutes % 60) {
    case (0, let m): "\(m)분"
    case (let h, 0): "\(h)시간"
    case (let h, let m): "\(h)시간 \(m)분"
    }
}
