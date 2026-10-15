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
    private var painCard: some View {
        let value = data?.pain.map { RecordDisplay.number(abs($0.difference)) + "점" } ?? "기록 없음"
        let subtitle = data?.pain?.previousDayDifference.map { "어제 " + changeText($0) } ?? "어제 기록 없음"
        return RecordOverviewCard(label: "통증 기록", value: data?.pain.map { changeText($0.difference) + ", " + subtitle } ?? value,
                                  action: selection(.pain), graphic: { RecordPainMiniChart(data: data?.pain) }) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    heading("통증", value)
                    if let difference = data?.pain?.difference, difference != 0 {
                        Image("RecordsChangeTriangle").frame(width: 10.6632, height: 9.5)
                            .rotationEffect(.degrees(difference > 0 ? 180 : 0))
                    }
                }
                caption(subtitle)
            }
        }.accessibilityIdentifier("records.pain")
    }
    private var symptomCard: some View {
        let value = data?.symptom?.presentCount.map { "\($0)건" } ?? (data?.symptom == nil ? "기록 없음" : "집계 미제공")
        let subtitle = data?.symptom?.types.map(\.displayName).joined(separator: ", ") ?? ""
        return RecordOverviewCard(label: "증상 기록", value: value + ", " + subtitle, action: selection(.symptom),
                                  graphic: { RecordSymptomCountBadge(count: data?.symptom?.presentCount) }) {
            VStack(alignment: .leading, spacing: 7) {
                heading("증상 기록", value)
                caption("있음으로 답한 항목")
                if !subtitle.isEmpty { caption(subtitle) }
            }
        }.accessibilityIdentifier("records.symptom")
    }
    private func heading(_ title: String, _ value: String) -> some View {
        Text("\(Text(title).fontWeight(.semibold))\(Text(value.isEmpty ? "" : " " + value).fontWeight(.bold))")
            .modifier(RecordTextStyle(size: 18)).foregroundStyle(.black).fixedSize(horizontal: false, vertical: true)
    }
    private func caption(_ text: String) -> some View {
        Text(text).modifier(RecordTextStyle(size: 12)).foregroundStyle(Color(white: 141 / 255)).fixedSize(horizontal: false, vertical: true)
    }
    private func selection(_ kind: RecordOverviewKind) -> (() -> Void)? {
        guard let onSelect, state.isLoaded else { return nil }
        return { onSelect(kind) }
    }
    private func changeText(_ difference: Double) -> String {
        RecordDisplay.number(abs(difference)) + "점 " + (difference > 0 ? "감소" : difference < 0 ? "증가" : "변화 없음")
    }
}

#Preview("조회 미연결") { RecordsView() }
