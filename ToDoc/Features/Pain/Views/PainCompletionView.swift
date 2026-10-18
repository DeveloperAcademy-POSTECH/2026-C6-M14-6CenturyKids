import SwiftUI

struct PainCompletionView: View {
    let record: PainCompletionData
    var onRecordAgain: (() -> Void)?
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    summary.padding(.top, 100)
                    Spacer(minLength: 52)
                    actions
                }
                .padding(.horizontal, AppSpacing.screenHorizontal).padding(.bottom, 2)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(AppColors.surface).toolbar(.hidden, for: .navigationBar)
    }

    private var summary: some View {
        VStack(spacing: 0) {
            Text("통증 변화가 기록됐어요")
                .appFont(.completionTitle)
                .multilineTextAlignment(.center).frame(minHeight: 32).padding(.top, AppSpacing.section)
            Text("약 복용 전후의 통증 정도를 비교해 정리했어요.")
                .appFont(.painBodySmall).foregroundStyle(AppColors.Text.secondary)
                .multilineTextAlignment(.center).frame(minHeight: 24).padding(.top, AppSpacing.compact)
            VStack(spacing: 0) {
                row("통증 부위") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { locationTags }.fixedSize()
                        VStack(alignment: .trailing, spacing: 6) { locationTags }
                    }
                }
                .overlay(alignment: .bottom) { Divider().overlay(AppColors.Pain.summaryDivider) }
                row("약 복용 전") { Text("\(record.painBefore)/10").appFont(.value) }
                    .overlay(alignment: .bottom) { Divider().overlay(AppColors.Pain.summaryDivider) }
                row("약 복용 후") { Text("\(record.painAfter)/10").appFont(.value) }
            }
            .padding(.horizontal, 20).padding(.top, 28)
            HStack(spacing: 2) {
                Text(changeDescription).appFont(.painCaption).multilineTextAlignment(.center)
                    .frame(minHeight: 21)
                if record.painChange > 0 {
                    Image("PainChangeDown").frame(width: 13.2, height: 12.54).accessibilityHidden(true)
                }
            }
            .foregroundStyle(AppColors.surface).padding(.horizontal, 16).padding(.vertical, AppSpacing.item)
            .frame(maxWidth: .infinity).appSurface(.painChange)
            .padding(.top, AppSpacing.columnGap)
        }
        .padding(.horizontal, 28).padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .appSurface(.painSummary)
    }

    @ViewBuilder private var locationTags: some View {
        ForEach(record.location, id: \.self) { location in
            Text(painLocationName(location, among: record.location)).appFont(.painCaption)
                .foregroundStyle(AppColors.Text.subdued).padding(.horizontal, 10).padding(.vertical, AppSpacing.tight)
                .background(AppColors.surface, in: Capsule())
                .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName)")
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.item) {
                    Text(title).appFont(.painBodySmall)
                    content()
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: AppSpacing.item) {
                    Text(title).appFont(.painBodySmall).fixedSize()
                    Spacer(minLength: 0)
                    content()
                }
            }
        }
        .padding(.vertical, AppSpacing.item).frame(minHeight: 64)
    }

    private var changeDescription: String {
        if record.painChange > 0 { return "복용 전보다 통증이 \(record.painChange)점 줄었어요." }
        if record.painChange < 0 { return "복용 전보다 통증이 \(-record.painChange)점 늘었어요." }
        return "복용 전후의 통증 점수가 같아요."
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.columnGap) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: AppSpacing.columnGap)) : AnyLayout(HStackLayout(spacing: AppSpacing.columnGap))
            layout {
                action("다시 기록하기", onRecordAgain)
                action("기록 보기", onShowRecord)
            }
            Button("홈으로") { onHome?() }
                .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onHome == nil)
        }
    }

    private func action(_ title: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            AppForwardLabel(title: title, asset: "PainNext", placement: .inline)
        }.buttonStyle(AppButtonStyle()).disabled(action == nil)
    }
}
