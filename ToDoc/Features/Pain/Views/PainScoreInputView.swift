import SwiftUI

struct PainScoreInputView: View {
    let locations: [BodyLocation]
    @Binding var score: Int?
    var before: Int?
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

    var body: some View {
        VStack(spacing: 0) {
            if typeSize.isAccessibilitySize {
                // 큰 글자에서는 안내/버튼이 게이지를 가리지 않도록 전체를 스크롤합니다.
                ScrollView { VStack(spacing: 24) { header; locationChip; gauge } }
            } else {
                // Figma Pain Scale Area: 칩 아래 남은 자리의 세로 가운데에 게이지를 둡니다. 자리가 모자라면 스크롤합니다.
                ViewThatFits(in: .vertical) {
                    inputContent
                    ScrollView { inputContent }
                }
            }
            footer
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
            gauge.frame(maxHeight: .infinity).padding(.top, 24)
        }
    }

    @ViewBuilder private var header: some View {
        if before == nil {
            // Figma 6-1: Header(제목 + 설명), 아래 칩까지 24
            PainHeader(title: "약을 먹기 전, 얼마나 아프세요?", description: "손잡이를 위아래로 움직여 점수를 골라주세요")
                .padding(.top, typeSize.isAccessibilitySize ? 76 : 36)
                .padding(.bottom, 24)
        } else {
            // Figma 9: 작은 윗글 + 제목, 아래 칩까지 16
            VStack(spacing: 8) {
                Text("약 먹고 1시간 뒤").appTypography(.body).foregroundStyle(AppColors.Semantic.Text.sub)
                Text("지금 통증은 어떤가요?").appTypography(.title).foregroundStyle(AppColors.Semantic.Text.default)
                    .accessibilityAddTraits(.isHeader)
            }
            .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 24)
            .padding(.top, typeSize.isAccessibilitySize ? 76 : 32)
            .padding(.bottom, 16)
        }
    }

    private var locationChip: some View {
        PainMoreLocationsChip(title: painLocationSummary(locations)) { showsLocations = true }
            .padding(.horizontal, 24)
            .accessibilityIdentifier("pain.score.locations")
    }

    /// 고르기 전에는 먹기 전 10점, 먹은 뒤 0점 자리에 보여 주기만 합니다 (score는 nil로 남아 다음을 막습니다)
    private var gauge: some View {
        PainScoreGauge(value: $score, initialValue: before == nil ? 10 : 0, before: before,
                       label: before == nil ? "약 복용 전 통증 점수" : "약 복용 후 통증 점수",
                       descriptor: painScoreWord, onInteractionEnded: onScoreInteractionEnded)
            .padding(.horizontal, 24).disabled(isSaving)
    }

    private var footer: some View {
        VStack(spacing: 24) {
            if let errorMessage { Text(errorMessage).font(.body).foregroundStyle(.red).padding(.horizontal, 24) }
            PainInputFooter(title: isSaving ? "저장 중" : "통증 점수 저장하기", isEnabled: score != nil && !isSaving,
                            isPreviousEnabled: !isSaving, onPrevious: onPrevious, onNext: onNext)
        }
    }

}
