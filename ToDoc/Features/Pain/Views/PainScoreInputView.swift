import SwiftUI

struct PainScoreInputView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    /// 약을 먹은 뒤 점수를 받는 화면이면 true. 0점부터 고를 수 있고 제목과 버튼 글자가 달라집니다.
    var isAfter = false
    var isSaving = false
    var errorMessage: String?
    var onPrevious: (() -> Void)?
    /// 있으면 고른 부위 시트에 '부위 다시 고르기'를 보여 줍니다. 먹은 뒤 점수는 부위가 이미 저장돼 없습니다.
    var onReselectLocations: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: (() -> Void)?
    var onScoreInteractionEnded: ((Int) -> Void)?

    @State private var showsLocations = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var usesExpandedLayout: Bool { typeSize > .large }

    var body: some View {
        VStack(spacing: 0) {
            if usesExpandedLayout {
                ScrollView {
                    inputContent
                    footer.padding(.top, 24)
                }
            } else {
                // 내용은 위에서부터 놓고, 자리가 모자라면 스크롤합니다.
                ViewThatFits(in: .vertical) {
                    inputContent
                    ScrollView { inputContent }
                }
                footer
            }
        }
        .background(AppColors.Semantic.Background.surface)
        .painBackButton(action: onClose, reservesSpace: usesExpandedLayout)
        .toolbar(.hidden, for: .navigationBar)
        .painSheet(isPresented: $showsLocations) {
            PainLocationSheet(locations: locations, onReselect: onReselectLocations.map { reselect in
                { showsLocations = false; reselect() }
            }, onClose: { showsLocations = false })
        }
    }

    private var inputContent: some View {
        VStack(spacing: 0) {
            header
            locationChip
            // Figma: 칩(높이 40) → 숫자 60. 칩은 누를 자리 때문에 위아래로 2씩 더 차지합니다
            scale.padding(.top, 58)
            Spacer(minLength: 24)
        }
    }

    /// Figma Header 92: 제목만 쓰고 설명 줄 자리(8 + 20)는 비워 둡니다
    private var header: some View {
        AppNavigation.Header(isAfter ? "약을 먹은 후 얼마나 아프세요?" : "약을 먹기 전 얼마나 아프세요?")
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
            .padding(.bottom, 24)
    }

    private var locationChip: some View {
        PainMoreLocationsChip(locations: locations) { showsLocations = true }
            .padding(.horizontal, AppLayout.Phone.horizontalMargin)
            .accessibilityIdentifier("pain.score.locations")
    }

    /// 고르기 전에는 채움 없이 "–"만 보여 줍니다 (score는 nil로 남아 저장을 막습니다)
    private var scale: some View {
        AppFeedback.PainScale(value: $score, range: isAfter ? 0...10 : 1...10,
                              label: isAfter ? "약 복용 후 통증 점수" : "약 복용 전 통증 점수",
                              placeholder: "막대를 좌우로 밀어 골라주세요",
                              descriptor: painScoreDescription, onInteractionEnded: onScoreInteractionEnded)
            .padding(.horizontal, AppLayout.Phone.horizontalMargin).disabled(isSaving)
    }

    private var footer: some View {
        VStack(spacing: 24) {
            if let errorMessage { Text(errorMessage).appTypography(.body).foregroundStyle(AppColors.Semantic.Text.error).padding(.horizontal, AppLayout.Phone.horizontalMargin) }
            PainInputFooter(title: isSaving ? "저장 중" : (isAfter ? "기록하고 변화 보기" : "통증 점수 저장하기"), isEnabled: score != nil && !isSaving,
                            isPreviousEnabled: !isSaving, onPrevious: onPrevious, onNext: onNext)
        }
    }

}
