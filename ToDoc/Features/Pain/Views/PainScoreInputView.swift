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
    var descriptor: (Int) -> String? = { _ in nil }

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
            AppHeader(title: "통증 변화 기록", description: before == nil
                      ? "약을 복용하기 전 통증 강도는 어떠셨나요?"
                      : "약을 복용한 뒤의 통증 강도는 어떠셨나요?")
                .padding(.top, typeSize.isAccessibilitySize ? 44 : 0)
            PainLocationChips(locations: locations).padding(.horizontal, 24).padding(.top, 24)
            PainScoreGauge(value: $score, before: before,
                           label: before == nil ? "약 복용 전 통증 점수" : "약 복용 후 통증 점수",
                           descriptor: descriptor)
                .padding(.horizontal, 24).padding(.top, 24).disabled(isSaving)
        }
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 24) {
            if let errorMessage { Text(errorMessage).font(.body).foregroundStyle(.red).padding(.horizontal, 24) }
            Text("막대를 위아래로 움직여 통증 정도를 조절하세요")
                .appTextStyle(.caption).foregroundStyle(Color(white: 114 / 255))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            PainInputFooter(title: isSaving ? "저장 중" : "다음", isEnabled: score != nil && !isSaving,
                            isPreviousEnabled: !isSaving, onPrevious: onPrevious, onNext: onNext)
        }
    }

}
