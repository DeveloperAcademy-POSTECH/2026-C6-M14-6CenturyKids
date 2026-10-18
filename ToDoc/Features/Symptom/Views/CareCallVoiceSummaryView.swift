import SwiftUI

/// Editable patient words and selected facts; save is always an external callback.
struct CareCallVoiceSummaryView: View {
    @Binding var items: [CareCallVoiceSummaryItem]
    @Binding var editingItemID: UUID?
    var onBack: (() -> Void)?
    var onSave: (() -> Void)?
    @FocusState private var focusedItemID: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.question) {
                VStack(spacing: AppSpacing.item) {
                    Text("요약").appFont(.sectionTitle)
                    Text("말씀해 주신 내용을 모았어요.\n저장하기 전에 확인하고 수정해 주세요.")
                        .appFont(.bodySmall).lineSpacing(6)
                        .foregroundStyle(AppColors.Text.control)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                VStack(spacing: AppSpacing.section) {
                    ForEach($items) { $item in
                        entry(item: $item)
                    }
                    if items.isEmpty {
                        Text("표시할 증상 기록이 없어요.")
                            .appFont(.body)
                            .foregroundStyle(AppColors.CareCall.summarySecondary)
                    }
                }
                Button { onSave?() } label: { AppForwardLabel(title: "저장하기", asset: "CareConversationNext") }
                    .buttonStyle(AppButtonStyle())
                    .disabled(onSave == nil || editingItemID != nil)
                    .padding(.top, AppSpacing.columnGap)
                    .accessibilityIdentifier("carecall.voice.summary.save")
            }
            .padding(.horizontal, 20)
            .padding(.top, AppSpacing.question)
            .padding(.bottom, 2)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.surface)
        .overlay(alignment: .topLeading) {
            if editingItemID == nil {
                Button { onBack?() } label: {
                    Image("CareSummaryBack").frame(width: 40, height: 38.23)
                    .frame(width: AppMetrics.Control.minimumHitSize, height: AppMetrics.Control.minimumHitSize)
                    .contentShape(Rectangle()).offset(x: -2, y: -2.885)
                }
                .buttonStyle(.plain)
                .disabled(onBack == nil)
                .padding(.leading, AppSpacing.section)
                .accessibilityLabel("요약에서 돌아가기")
            }
        }
        .onAppear { focusedItemID = editingItemID }
        .onChange(of: editingItemID) { _, value in focusedItemID = value }
    }

    private func entry(item: Binding<CareCallVoiceSummaryItem>) -> some View {
        let itemID = item.wrappedValue.id
        let editing = editingItemID == itemID
        return VStack(spacing: AppSpacing.content) {
            HStack {
                Text(item.wrappedValue.title)
                    .appFont(.bodyStrong)
                Spacer()
                if editing {
                    Button("삭제", role: .destructive) {
                        items.removeAll { $0.id == itemID }
                        editingItemID = nil
                    }
                    .foregroundStyle(AppColors.Feedback.error)
                    .padding(.trailing, AppSpacing.section)
                    Button("완료") { editingItemID = nil }
                        .foregroundStyle(AppColors.CareCall.nativeDoneAction)
                } else {
                    Button("수정") { editingItemID = item.wrappedValue.id }
                        .foregroundStyle(AppColors.CareCall.editAction)
                        .disabled(editingItemID != nil)
                        .accessibilityLabel("\(item.wrappedValue.title) 수정")
                }
            }
            .appFont(.body)
            .buttonStyle(.plain)
            VStack(spacing: 0) {
                if let location = item.wrappedValue.location {
                    CareCallSummaryRow(title: "부위", spacing: AppSpacing.compact) {
                        Text(location).foregroundStyle(AppColors.CareCall.summarySecondary)
                    }
                    Divider()
                }
                if let frequency = item.wrappedValue.frequency {
                    CareCallSummaryRow(title: "횟수") {
                        if editing {
                            TextField("횟수", text: Binding(
                                get: { item.wrappedValue.frequency ?? "" },
                                set: { item.wrappedValue.frequency = $0 }), axis: .vertical)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("횟수")
                                .accessibilityIdentifier("carecall.voice.summary.frequency")
                        } else {
                            Text(frequency).foregroundStyle(AppColors.CareCall.summarySecondary)
                        }
                    }
                    Divider()
                }
                if let duration = item.wrappedValue.duration {
                    CareCallSummaryRow(title: "지속 시간") {
                        if editing {
                            TextField("지속 시간", text: Binding(
                                get: { item.wrappedValue.duration ?? "" },
                                set: { item.wrappedValue.duration = $0 }), axis: .vertical)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("지속 시간")
                                .accessibilityIdentifier("carecall.voice.summary.duration")
                        } else {
                            Text(duration).foregroundStyle(AppColors.CareCall.summarySecondary)
                        }
                    }
                    Divider()
                }
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    Text(item.wrappedValue.detailLabel)
                    if editing {
                        TextField(item.wrappedValue.detailLabel, text: item.detail, axis: .vertical)
                            .focused($focusedItemID, equals: item.wrappedValue.id)
                            .accessibilityIdentifier("carecall.voice.summary.detail")
                    } else {
                        Text(item.wrappedValue.detail.isEmpty ? "입력한 말이 없어요." : item.wrappedValue.detail)
                            .foregroundStyle(AppColors.CareCall.summarySecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.section)
            }
            .font(AppTypography.NativeConversation.body)
            .padding(.horizontal, 16)
            .appSurface(.conversationSummary)
        }
    }
}

/// Native 편집 행의 폰트·68pt 높이를 유지하는 접근성 레이아웃입니다.
private struct CareCallSummaryRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var spacing: CGFloat = AppSpacing.content
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    Text(title)
                    content().frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: spacing) {
                    Text(title)
                    Spacer(minLength: AppSpacing.compact)
                    content()
                }
            }
        }
        .frame(minHeight: 68)
    }
}
