import SwiftUI

/// 먹기 전 통증만 기록한 지 1시간이 지났을 때, 그 기록을 이어 갈지 새로 기록할지 고릅니다.
struct PainRecordChoiceView: View {
    let locations: [BodyLocation]
    let before: Int
    let recordedDate: Date
    var onContinue: (() -> Void)?
    var onNewRecord: (() -> Void)?
    var onClose: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    AppHeader(title: "복용 후 통증을 기록할 차례예요",
                              description: "\(recordedText) 약 복용 전 통증을 \(before)점으로 기록했어요.")
                        .padding(.top, typeSize.isAccessibilitySize ? 44 : 0)
                    PainLocationChips(locations: locations).padding(.horizontal, 24).padding(.top, 24)
                }
                .padding(.bottom, 24)
            }
            VStack(spacing: 12) {
                Button("기존 통증 마저 기록하기") { onContinue?() }
                    .buttonStyle(AppButtonStyle()).disabled(onContinue == nil)
                Button("새로운 통증 기록하기") { onNewRecord?() }
                    .buttonStyle(AppButtonStyle(kind: .secondary)).disabled(onNewRecord == nil)
            }
            .padding(.horizontal, 24).padding(.bottom, 12)
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

    /// 오늘 기록이면 시각만, 지난 기록이면 날짜와 시각을 보여 줍니다.
    private var recordedText: String {
        Calendar.current.isDateInToday(recordedDate)
            ? recordedDate.formatted(date: .omitted, time: .shortened)
            : recordedDate.formatted(.dateTime.month().day().hour().minute())
    }
}

#Preview {
    PainRecordChoiceView(locations: [.init(bodyPart: .chest, bodySide: .center, bodyView: .front)],
                         before: 7, recordedDate: .now.addingTimeInterval(-90 * 60),
                         onContinue: {}, onNewRecord: {}, onClose: {})
}
