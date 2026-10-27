import SwiftUI

struct PainCompletionView: View {
    let record: PainCompletionData
    var isSaving = false
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
                .padding(.horizontal, 24).padding(.bottom, 2)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(.white).toolbar(.hidden, for: .navigationBar)
    }

    private var summary: some View {
        VStack(spacing: 0) {
            Text("통증 변화를 확인해 주세요")
                .modifier(PainTextStyle(size: 24, weight: .bold))
                .multilineTextAlignment(.center).padding(.top, 24)
            Text("약 복용 전후의 통증 정도를 비교해 정리했어요.")
                .modifier(PainTextStyle(size: 15)).foregroundStyle(Color(white: 114 / 255))
                .multilineTextAlignment(.center).padding(.top, 8)
            VStack(spacing: 0) {
                row("통증 부위") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { locationTags }.fixedSize()
                        VStack(alignment: .trailing, spacing: 6) { locationTags }
                    }
                }
                Divider().overlay(Color(white: 213 / 255))
                row("약 복용 전") { Text("\(record.painBefore)/10").modifier(PainTextStyle(size: 18, weight: .semibold)) }
                Divider().overlay(Color(white: 213 / 255))
                row("약 복용 후") {
                    Text(record.painAfter.map { "\($0)/10" } ?? "미기록")
                        .modifier(PainTextStyle(size: 18, weight: .semibold))
                }
            }
            .padding(.horizontal, 20).padding(.top, 28)
            HStack(spacing: 2) {
                if let description = changeDescription {
                    Text(description).modifier(PainTextStyle(size: 14)).multilineTextAlignment(.center)
                }
                if let painChange = record.painChange {
                    if painChange > 0 {
                        Image("PainChangeDown").frame(width: 13.2, height: 12.54).accessibilityHidden(true)
                    }
                }
            }
            .foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity).background(Color(red: 104 / 255, green: 100 / 255, blue: 104 / 255), in: RoundedRectangle(cornerRadius: 20))
            .padding(.top, 20)
        }
        .padding(.horizontal, 28).padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(Color(white: 244 / 255), in: RoundedRectangle(cornerRadius: 32))
    }

    @ViewBuilder private var locationTags: some View {
        ForEach(record.location, id: \.self) { location in
            Text(painLocationName(location, among: record.location)).modifier(PainTextStyle(size: 14))
                .foregroundStyle(Color(white: 79 / 255)).padding(.horizontal, 10).padding(.vertical, 4)
                .background(.white, in: Capsule())
                .accessibilityLabel("\(painLocationName(location)) \(location.bodyView.displayName)")
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).modifier(PainTextStyle(size: 15))
                    content()
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    Text(title).modifier(PainTextStyle(size: 15)).fixedSize()
                    Spacer(minLength: 0)
                    content()
                }
            }
        }
        .padding(.vertical, 12).frame(minHeight: 64)
    }

    private var changeDescription: String? {
        if let painChange = record.painChange {
            if painChange > 0 { return "복용 전보다 통증이 \(painChange)점 줄었어요." }
            if painChange < 0 { return "복용 전보다 통증이 \(-painChange)점 늘었어요." }
            return "복용 전후의 통증 점수가 같아요."
        } else {
            return "아직 사후 통증을 기록하지 않았어요."
        }
    }

    private var actions: some View {
        VStack(spacing: 20) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(spacing: 20))
            layout {
                action("다시 기록하기", onRecordAgain)
                action("기록 보기", onShowRecord)
            }
            Button("홈으로") { onHome?() }
                .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onHome == nil || isSaving)
        }
    }

    private func action(_ title: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            HStack(spacing: 4) {
                Text(title)
                Image("CareConversationNext").frame(width: 12, height: 12).accessibilityHidden(true)
            }
        }.buttonStyle(AppButtonStyle()).disabled(action == nil || isSaving)
    }
}
