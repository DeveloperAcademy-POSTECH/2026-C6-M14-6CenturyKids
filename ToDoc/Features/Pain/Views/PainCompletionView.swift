import SwiftUI

/// Figma '통증 부위 선택 플로우' 결과 화면: 먹기 전과 1시간 뒤 점수를 캡슐로 나란히 보여 줍니다.
/// 캡슐·화살표·제목 규칙은 Figma 규칙표(개발 전달)를 따릅니다.
struct PainCompletionView: View {
    let record: PainCompletionData
    var onShowRecord: (() -> Void)?
    var onHome: (() -> Void)?

    @State private var showsLocations = false
    @State private var showsUsage = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    summary
                    capsules
                }
                .padding(.horizontal, 24).padding(.top, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Figma Content는 위아래로 벌려 아코디언을 버튼 바로 위에 둡니다
            usage.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
            AppActions.BottomAction(primary: .init("홈으로 돌아가기", isEnabled: onHome != nil) { onHome?() },
                                    subAction: .init("기록 보기", isEnabled: onShowRecord != nil) { onShowRecord?() })
        }
        .background(AppColors.Semantic.Background.surface)
        .toolbar(.hidden, for: .navigationBar)
        .painSheet(isPresented: $showsLocations) {
            PainLocationSheet(locations: record.location, onClose: { showsLocations = false })
        }
    }

    private var summary: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("약 먹고 1시간 뒤").appTypography(.body).foregroundStyle(AppColors.Semantic.Text.sub)
                Text(title).appTypography(.title).foregroundStyle(AppColors.Semantic.Text.default)
                    .accessibilityAddTraits(.isHeader)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            PainMoreLocationsChip(title: painLocationSummary(record.location)) { showsLocations = true }
                .accessibilityIdentifier("pain.result.locations")
        }
    }

    /// Figma 규칙표 제목 문구
    private var title: String {
        guard let change = record.painChange else { return "통증 변화가 기록됐어요" }
        if change > 0 { return "통증이 \(change)점 낮아졌어요" }
        if change < 0 { return "통증이 \(-change)점 높아졌어요" }
        return "통증이 그대로예요"
    }

    /// Figma 캡슐 영역: 높이 274로 고정해 점수가 바뀌어도 바닥·라벨 위치가 같습니다.
    private var capsules: some View {
        HStack(alignment: .bottom, spacing: 28) {
            VStack(spacing: 10) {
                PainScoreCapsule(score: record.painBefore)
                Text("먹기 전").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
            }
            if let after = record.painAfter {
                VStack(spacing: 10) {
                    PainScoreCapsule(score: after, isAfter: true, change: record.painChange)
                    Text("1시간 뒤").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.default)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 274, alignment: .bottom)
    }

    /// Figma How this record is used: 처음에는 접혀 있습니다.
    private var usage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { showsUsage.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("이 기록은 이렇게 쓰여요").appTypography(.labelLarge)
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.Semantic.Text.default)
                        .rotationEffect(.degrees(showsUsage ? 180 : 0))
                        .frame(width: 24, height: 24).accessibilityHidden(true)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(AppActions.PressStyle())
            .padding(.vertical, -10)
            .accessibilityValue(showsUsage ? "펼침" : "접힘")
            .accessibilityIdentifier("pain.result.usage")
            if showsUsage {
                ForEach(Array(Self.usageItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)").appTypography(.label).foregroundStyle(AppColors.Semantic.Text.action)
                        Text(item).appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.default)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.Semantic.Background.default, in: RoundedRectangle(cornerRadius: 16))
    }

    private static let usageItems = [
        "기록 탭에서 오늘 날짜로 다시 볼 수 있어요",
        "진료 전에 이 기록을 골라 선생님께 보낼 수 있어요",
        "기록이 쌓일수록 맞는 약을 선생님과 찾기 쉬워져요"
    ]
}

#Preview("내려감 8 → 5") {
    PainCompletionView(record: .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front),
                                                .init(bodyPart: .backLowerBack, bodySide: .center, bodyView: .back)],
                                     painBefore: 8, painAfter: 5, painChange: 3),
                       onShowRecord: {}, onHome: {})
}

#Preview("올라감 0 → 10") {
    PainCompletionView(record: .init(location: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                                     painBefore: 0, painAfter: 10, painChange: -10),
                       onShowRecord: {}, onHome: {})
}
