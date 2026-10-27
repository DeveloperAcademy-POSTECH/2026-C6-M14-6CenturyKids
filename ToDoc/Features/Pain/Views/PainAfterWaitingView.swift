import SwiftUI

/// 먹기 전 통증을 저장하고 1시간이 지나기 전에 들어오면 보이는 화면입니다.
/// 먹은 뒤 통증 화면을 흐리게 깔고 남은 시간을 보여 줍니다.
struct PainAfterWaitingView: View {
    let locations: [BodyLocation]
    let before: Int
    let availableDate: Date
    var onNewRecord: (() -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
        PainScoreInputView(locations: locations, score: .constant(0), before: before)
            .blur(radius: 8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay { notice.padding(.horizontal, 24) }
            .toolbar(.hidden, for: .navigationBar)
    }

    private var notice: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = Self.remainingText(until: availableDate, now: context.date)
                VStack(spacing: 8) {
                    Text("\(remaining) 뒤에 기록해주세요")
                        .modifier(PainTextStyle(size: 22, weight: .bold))
                        .monospacedDigit()
                        .accessibilityAddTraits(.isHeader)
                    Text("약을 드시고 1시간이 지나면 복용 후 통증을 기록할 수 있어요.")
                        .modifier(PainTextStyle(size: 15)).foregroundStyle(Color(white: 114 / 255))
                }
                .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button("새로운 통증 기록하기") { onNewRecord?() }
                    .buttonStyle(AppButtonStyle()).disabled(onNewRecord == nil)
                Button("닫기") { onClose?() }
                    .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onClose == nil)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
    }

    /// 남은 시간을 MM:SS로 보여 줍니다. 초는 올림해 00:00이 되면 바로 기록할 수 있습니다.
    static func remainingText(until date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    PainAfterWaitingView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                         before: 7, availableDate: .now.addingTimeInterval(42 * 60 + 5),
                         onNewRecord: {}, onClose: {})
}
