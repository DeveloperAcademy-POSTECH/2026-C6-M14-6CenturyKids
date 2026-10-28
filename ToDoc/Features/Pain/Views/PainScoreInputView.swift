import SwiftUI

struct PainScoreInputView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    var before: Int?
    var isSaving = false
    var errorMessage: String?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // 큰 글자에서는 안내/버튼이 게이지를 가리지 않도록 전체를 스크롤합니다.
                ScrollView { VStack(spacing: 24) { inputContent; footer } }
            } else {
                VStack(spacing: 0) {
                    ScrollView { inputContent }
                    footer
                }
            }
        }
        .background(.white)
        .overlay(alignment: .topLeading) {
            if let onClose {
                Button(action: onClose) { Image("PainBack").frame(width: 40, height: 40) }
                    .buttonStyle(.plain).padding(.leading, 24).padding(.top, 5)
                    .accessibilityLabel("통증 기록에서 돌아가기")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var inputContent: some View {
        VStack(spacing: 0) {
            AppHeader(title: before == nil
                      ? "약을 먹기 전, 얼마나 아프세요?"
                      : "약을 먹은 후, 지금은 얼마나 아프세요?",
                      description: "손잡이를 위아래로 움직여 점수를 골라주세요")
                .padding(.top, typeSize.isAccessibilitySize ? 44 : 0)
            PainLocationChips(locations: locations).padding(.horizontal, 24).padding(.top, 24)
            PainScoreGauge(value: $score, before: before,
                           label: before == nil ? "약 복용 전 통증 점수" : "약 복용 후 통증 점수")
                .padding(.horizontal, 24).padding(.top, 24).disabled(isSaving)
        }
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 24) {
            if let errorMessage { Text(errorMessage).font(.body).foregroundStyle(.red).padding(.horizontal, 24) }
            PainInputFooter(title: isSaving ? "저장 중" : "통증 점수 저장하기", isEnabled: score != nil && !isSaving,
                            isPreviousEnabled: !isSaving, onPrevious: onPrevious, onNext: onNext)
        }
    }

}
