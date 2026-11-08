import SwiftUI

/// Figma '통증 부위 선택 플로우' 8~8-D: 먹기 전 통증을 저장한 뒤 1시간 뒤 기록까지 기다리는 화면입니다.
/// 1시간이 지나야 기록할 수 있습니다. 기다리는 동안에는 확인 창을 거쳐 새로운 통증을 기록할 수 있고,
/// 그러면 이 기록은 먹기 전 점수만 남습니다.
struct PainAfterTimerView: View {
    let locations: [BodyLocation]
    let before: Int
    let recordedDate: Date
    let availableDate: Date
    var remindersAllowed = true
    var onLater: (() -> Void)?
    var onRecord: (() -> Void)?
    var onNewRecord: (() -> Void)?
    /// 피그마에는 없지만, 시간이 다 되면 기록 말고 나갈 길이 없어 다른 통증 화면처럼 둡니다.
    var onClose: (() -> Void)?
    var onStateViewed: ((String) -> Void)?

    @State private var showsLocations = false
    @State private var showsNewRecordConfirmation = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = Phase(now: context.date, recordedDate: recordedDate, availableDate: availableDate)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        summary(phase)
                        capsules(phase, now: context.date)
                    }
                    .padding(.horizontal, 24).padding(.top, 32)
                }
                .scrollBounceBehavior(.basedOnSize)
                infoBox(phase).padding(.horizontal, 24).padding(.vertical, 24)
                bottomAction(phase)
            }
            .onChange(of: phase.analyticsState, initial: true) { _, state in
                onStateViewed?(state)
            }
        }
        .background(AppColors.Semantic.Background.surface)
        .overlay(alignment: .topLeading) {
            if let onClose {
                Button(action: onClose) { Image("PainBack").frame(width: 40, height: 40) }
                    .buttonStyle(.plain).padding(.leading, 24).padding(.top, 5)
                    .accessibilityLabel("통증 기록에서 돌아가기")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .painSheet(isPresented: $showsLocations) {
            PainLocationSheet(locations: locations, onClose: { showsLocations = false })
        }
        .overlay {
            if showsNewRecordConfirmation {
                ZStack {
                    // Figma 8-A 자리: 뒤 화면은 background/inverse 40% 막, 제목은 title 크기
                    AppColors.Semantic.Background.inverse.opacity(0.4).ignoresSafeArea().accessibilityHidden(true)
                    AppFeedback.Dialog("새로운 통증을 기록할까요?", titleStyle: .title,
                                       message: "새로운 통증을 기록하면 이전 통증 기록은\n약물 복용 후 점수를 기록하지 못 합니다.",
                                       primary: .init("새로운 통증 기록하기") {
                                           showsNewRecordConfirmation = false
                                           onNewRecord?()
                                       },
                                       secondary: .init("닫기") { showsNewRecordConfirmation = false })
                        .padding(.horizontal, AppLayout.Phone.horizontalMargin)
                        .accessibilityAddTraits(.isModal)
                }
            }
        }
    }

    enum Phase: Equatable {
        case waiting(remaining: TimeInterval, progress: Double)
        case ready
        /// 먹기 전 기록에서 이만큼 시간이 지나서야 돌아왔습니다 (Figma 8-C)
        case late(hours: Int)

        var analyticsState: String {
            switch self {
            case .waiting: "waiting"
            case .ready: "ready"
            case .late: "late"
            }
        }

        // ponytail: 늦었다고 보는 기준(먹기 전 기록에서 2시간)은 시안의 '3시간 뒤' 예시로 정한 값입니다. 기준이 정해지면 바꿉니다.
        static let lateAfter: TimeInterval = 2 * 60 * 60

        init(now: Date, recordedDate: Date, availableDate: Date) {
            let remaining = availableDate.timeIntervalSince(now)
            let elapsed = now.timeIntervalSince(recordedDate)
            if remaining > 0 {
                let total = max(1, availableDate.timeIntervalSince(recordedDate))
                self = .waiting(remaining: remaining, progress: min(1, max(0, 1 - remaining / total)))
            } else if elapsed >= Self.lateAfter {
                self = .late(hours: Int(elapsed / 3600))
            } else {
                self = .ready
            }
        }
    }

    private var availableTime: String {
        availableDate.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ko_KR")))
    }

    private func summary(_ phase: Phase) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("약 먹기 전 \(before)점을 기록했어요")
                    .appTypography(.body).foregroundStyle(AppColors.Semantic.Text.sub)
                Text(title(phase))
                    .appTypography(.title).foregroundStyle(AppColors.Semantic.Text.default)
                    .accessibilityAddTraits(.isHeader)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            PainMoreLocationsChip(title: painLocationSummary(locations)) { showsLocations = true }
                .accessibilityIdentifier("pain.timer.locations")
        }
    }

    private func title(_ phase: Phase) -> String {
        switch phase {
        case .waiting: "\(availableTime)에 다시 기록해 주세요"
        case .ready: "이제 다시 기록해 주세요"
        case .late: "지금 기록해도 괜찮아요"
        }
    }

    /// Figma Capsules: 먹기 전 캡슐(높이 144 + 점수 × 10)과 1시간 뒤 원(144)을 바닥에 맞춰 놓습니다.
    private func capsules(_ phase: Phase, now: Date) -> some View {
        HStack(alignment: .bottom, spacing: 28) {
            VStack(spacing: 10) {
                PainScoreCapsule(score: before)
                Text("먹기 전").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
            }
            VStack(spacing: 10) {
                afterCircle(phase)
                Text("1시간 뒤 · \(availableTime)").appTypography(.bodySmall)
                    .foregroundStyle(AppColors.Semantic.Text.default)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 274, alignment: .bottom)
    }

    private func afterCircle(_ phase: Phase) -> some View {
        Group {
            switch phase {
            case let .waiting(remaining, progress):
                VStack(spacing: 8) {
                    Text(PainAfterTimerView.remainingText(remaining)).appTypography(.headline).monospacedDigit()
                        .foregroundStyle(AppColors.Semantic.Text.default)
                    Text("남았어요").appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
                }
                .frame(width: 144, height: 144)
                .background(alignment: .bottom) {
                    // Figma 차오름(지난 시간): 아래에서부터 지난 만큼 채웁니다
                    ZStack(alignment: .bottom) {
                        AppColors.Semantic.Background.default
                        LinearGradient(colors: [AppColors.Semantic.Primary.default.opacity(0.9),
                                                AppColors.Semantic.Primary.default.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 144 * progress)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("1시간 뒤 기록까지 \(Int(remaining / 60) + 1)분 남았어요")
            case .ready, .late:
                VStack(spacing: 2) {
                    Text("기록할")
                    Text("시간이에요")
                }
                .appTypography(.title).foregroundStyle(AppColors.Semantic.Text.default)
                .frame(width: 144, height: 144)
                .background(AppColors.Semantic.Primary.default)
                .accessibilityElement(children: .combine)
            }
        }
        .clipShape(Circle())
    }

    private func infoBox(_ phase: Phase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .waiting where !remindersAllowed:
                infoText("알림이 꺼져 있어서 \(availableTime)에 알려 드릴 수 없어요.")
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("알림 켜기 ›").appTypography(.label).foregroundStyle(AppColors.Semantic.Text.action)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(AppActions.PressStyle())
                .padding(.vertical, -12)
                .accessibilityIdentifier("pain.timer.enableReminder")
            case .waiting:
                infoText("약은 보통 15–30분이면 듣기 시작해요.\n약효가 가장 클 때인 1시간 뒤에 다시 기록해요.")
            case .ready:
                infoText("지금 기록하면 약 먹기 전과 비교해서 보여 드릴게요.")
            case let .late(hours):
                infoText("약 복용 후 \(hours)시간이 지났어요.\n지금 기록하면 약 먹기 전과 비교해서 보여 드릴게요.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.Semantic.Background.default, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoText(_ text: String) -> some View {
        Text(text).appTypography(.bodySmall).foregroundStyle(AppColors.Semantic.Text.sub)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func bottomAction(_ phase: Phase) -> some View {
        if case .waiting = phase {
            AppActions.BottomAction(primary: .init("1시간 뒤에 돌아오기", isEnabled: onLater != nil) { onLater?() },
                                    subAction: .init("새로운 통증 기록하기", isEnabled: onNewRecord != nil) {
                                        showsNewRecordConfirmation = true
                                    })
        } else {
            AppActions.BottomAction(primary: .init("선택 부위 통증 고르기", isEnabled: onRecord != nil) { onRecord?() })
        }
    }

    /// 남은 시간을 MM:SS로 보여 줍니다. 초는 올림해 00:00이 되면 바로 기록할 수 있습니다.
    static func remainingText(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview("기다리는 중") {
    PainAfterTimerView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front),
                                   .init(bodyPart: .backLowerBack, bodySide: .center, bodyView: .back)],
                       before: 8, recordedDate: .now.addingTimeInterval(-30 * 60),
                       availableDate: .now.addingTimeInterval(30 * 60), onLater: {}, onRecord: {}, onNewRecord: {})
}

#Preview("알림 꺼짐") {
    PainAfterTimerView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                       before: 8, recordedDate: .now, availableDate: .now.addingTimeInterval(60 * 60),
                       remindersAllowed: false, onLater: {}, onRecord: {})
}

#Preview("늦게 돌아옴") {
    PainAfterTimerView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                       before: 8, recordedDate: .now.addingTimeInterval(-3 * 60 * 60),
                       availableDate: .now.addingTimeInterval(-2 * 60 * 60), onLater: {}, onRecord: {})
}
