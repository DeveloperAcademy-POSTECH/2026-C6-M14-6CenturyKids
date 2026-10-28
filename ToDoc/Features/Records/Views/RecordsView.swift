import SwiftUI

/// 조회/날짜 선택은 소유 ViewModel이 처리하고 화면은 제공된 상태와 이동 콜백을 표시합니다.
/// 기본 호출은 미연결 상태이며 목업 기록을 제품에 노출하지 않습니다.
struct RecordsView: View {
    var dateLabel = "오늘"
    var snapshot: RecordOverviewSnapshot?
    var state: RecordOverviewDisplayState = .unavailable
    var onMoveDay: ((Int) -> Void)?
    var onSelect: ((RecordOverviewKind) -> Void)?
    var onRetry: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    private var data: RecordOverviewSnapshot? { state.isLoaded ? snapshot : nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                AppHeader(title: "내 기록")
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 4) {
                        Text(dateLabel).modifier(RecordTextStyle(size: 16)).multilineTextAlignment(.center)
                        HStack { dayArrow(-1); Spacer(); dayArrow(1) }
                    }
                } else {
                    HStack(spacing: 20) {
                        dayArrow(-1)
                        Text(dateLabel).modifier(RecordTextStyle(size: 16)).multilineTextAlignment(.center)
                        dayArrow(1)
                    }
                }
                VStack(spacing: 22) {
                    painCard
                    symptomCard
                }
                status
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(Color(white: 248 / 255))
    }
    private func dayArrow(_ direction: Int) -> some View {
        Button { onMoveDay?(direction) } label: {
            Image("RecordsDayArrow").frame(width: 5.5, height: 8.5)
                .rotationEffect(.degrees(direction < 0 ? 180 : 0)).frame(width: 44, height: 44)
        }.buttonStyle(.plain).disabled(onMoveDay == nil)
            .accessibilityLabel(direction < 0 ? "이전 날짜" : "다음 날짜")
    }
    @ViewBuilder private var status: some View {
        switch state {
        case .loaded: EmptyView()
        case .idle:
            Button("기록 불러오기") { onRetry?() }.buttonStyle(.bordered).disabled(onRetry == nil)
        case .loading: ProgressView("기록을 불러오고 있어요")
        case .unavailable: Text("기록 조회가 아직 연결되지 않았어요.").font(.body)
        case .failed(let message):
            Text(message).font(.body)
            Button("다시 시도") { onRetry?() }.buttonStyle(.bordered).disabled(onRetry == nil)
        }
    }
    // 카드 왼쪽 그래프는 시안 확정 전이라 자리만 둡니다.
    private var painCard: some View {
        // 그날 점수: 복용 후를 아직 적지 않았으면 복용 전만
        let subtitle = data?.pain.map { pain in
            let before = "복용 전 \(RecordDisplay.number(pain.averageBefore))점"
            return pain.averageAfter.map { before + " → 복용 후 \(RecordDisplay.number($0))점" } ?? before
        } ?? "기록 없음"
        return RecordOverviewCard(label: "통증", value: subtitle.replacingOccurrences(of: " → ", with: ", "),
                                  action: selection(.pain), graphic: { Color.clear }) {
            card("통증", subtitle)
        }.accessibilityIdentifier("records.pain")
    }
    private var symptomCard: some View {
        let subtitle = data?.symptom.map { symptom in
            symptom.types.isEmpty ? "있음으로 답한 증상 없음" : symptom.types.map(\.displayName).joined(separator: ", ")
        } ?? "기록 없음"
        return RecordOverviewCard(label: "증상", value: subtitle, action: selection(.symptom), graphic: { Color.clear }) {
            card("증상", subtitle)
        }.accessibilityIdentifier("records.symptom")
    }
    private func card(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).modifier(RecordTextStyle(size: 18, weight: .semibold)).foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
            caption(subtitle)
        }
    }
    private func caption(_ text: String) -> some View {
        Text(text).modifier(RecordTextStyle(size: 12)).foregroundStyle(Color(white: 141 / 255)).fixedSize(horizontal: false, vertical: true)
    }
    private func selection(_ kind: RecordOverviewKind) -> (() -> Void)? {
        guard let onSelect, state.isLoaded else { return nil }
        return { onSelect(kind) }
    }
}

#Preview("조회 미연결") { RecordsView() }
#Preview("기록 있음") {
    RecordsView(dateLabel: "10월 2일 화요일",
                snapshot: .init(pain: .init(averageBefore: 7, averageAfter: 5, difference: 2),
                                symptom: .init(presentCount: 2, types: [.nauseaVomiting, .dehydrationNutrition])),
                state: .loaded, onMoveDay: { _ in }, onSelect: { _ in })
}
