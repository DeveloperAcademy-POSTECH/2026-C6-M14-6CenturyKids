import SwiftUI

struct RecordDetailLayout<Content: View>: View {
    let state: RecordDetailScreenState
    var editing = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                periodPicker
                HStack(spacing: 12) {
                    RecordDateArrow(direction: -1, label: "이전 기간", disabled: editing || state.onAction == nil) { state.onAction?(.movePeriod(-1)) }
                    Text(state.periodLabel).modifier(RecordTextStyle(size: 16)).multilineTextAlignment(.center)
                    RecordDateArrow(direction: 1, label: "다음 기간", disabled: editing || state.onAction == nil) { state.onAction?(.movePeriod(1)) }
                }.padding(.vertical, 4)
                if state.loadState.isLoaded { content() }
                else { RecordQueryStatus(state: state.loadState) { state.onAction?(.load) } }
            }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(white: 248 / 255))
        .navigationTitle(state.kind == .symptom ? "하루 기록" : "통증")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { state.onAction?(.load) }
        .onDisappear { state.onAction?(.cancel) }
    }
    private var periodPicker: some View {
        HStack(spacing: 16) {
            ForEach(RecordPeriod.allCases, id: \.self) { period in
                Button { state.onAction?(.selectPeriod(period)) } label: {
                    Text(period.displayName).modifier(RecordTextStyle(size: 16))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .foregroundStyle(state.period == period ? .white : Color(white: 0.45))
                        .background(state.period == period ? Color(red: 104/255, green: 100/255, blue: 104/255) : .clear, in: Capsule())
                        .overlay { if state.period == period { Capsule().strokeBorder(Color(white: 120/255), lineWidth: 2) } }
                }.buttonStyle(.plain).disabled(editing || state.onAction == nil)
                    .accessibilityLabel(period.displayName + "별 기록").accessibilityAddTraits(state.period == period ? .isSelected : [])
            }
        }.padding(8).background(Color(white: 232/255), in: Capsule())
            .overlay { Capsule().strokeBorder(Color(white: 223/255), lineWidth: 2) }
    }
}

struct RecordDateArrow: View {
    let direction: Int
    let label: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image("RecordsDayArrow").frame(width: 5.5, height: 8.5)
                .rotationEffect(.degrees(direction < 0 ? 180 : 0)).frame(width: 44, height: 44)
        }.buttonStyle(.plain).disabled(disabled).accessibilityLabel(label)
    }
}

struct RecordQueryStatus: View {
    let state: RecordOverviewDisplayState
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            switch state {
            case .loading: ProgressView("기록을 불러오고 있어요")
            case .idle: Button("기록 불러오기", action: retry).buttonStyle(.bordered)
            case .unavailable: Text("기록 조회가 아직 연결되지 않았어요.")
            case .failed(let message): Text(message); Button("다시 시도", action: retry).buttonStyle(.bordered)
            case .loaded: EmptyView()
            }
        }.padding(24).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 26))
    }
}

struct RecordChartCard<Chart: View>: View {
    let caption: String
    let value: String
    let range: String
    @ViewBuilder var chart: () -> Chart
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption).modifier(RecordTextStyle(size: 14)).foregroundStyle(Color(white: 141/255))
            Text(value).modifier(RecordTextStyle(size: 26, weight: .bold)).foregroundStyle(Color(red: 25/255, green: 28/255, blue: 23/255))
            Text(range).modifier(RecordTextStyle(size: 10)).foregroundStyle(Color(white: 141/255))
            chart().padding(.top, 30)
        }.padding(.horizontal, 22).padding(.top, 35).padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 26))
    }
}

/// 실제 조회 기간의 축을 그립니다. 평균값은 이 컴포넌트에서 계산하지 않습니다.
struct RecordPlot<Marks: View>: View {
    var scoreAxis = true
    @ViewBuilder var marks: (_ size: CGSize) -> Marks
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(0...10, id: \.self) { value in
                    let y = proxy.size.height * CGFloat(10 - value) / 10
                    if value.isMultiple(of: 5) {
                        Rectangle().fill(Color(white: 230/255)).frame(height: 1).offset(y: y)
                        if scoreAxis {
                            Text(String(value)).modifier(RecordTextStyle(size: 12)).foregroundStyle(Color(white: 141/255))
                                .offset(x: -21, y: y - 8)
                        }
                    }
                }
                marks(proxy.size)
            }
        }.frame(height: 237).padding(.leading, scoreAxis ? 20 : 0)
    }
}

@MainActor enum RecordChartStyle {
    static let symptom = LinearGradient(colors: [Color(red: 144/255, green: 227/255, blue: 60/255), Color(red: 232/255, green: 251/255, blue: 138/255)], startPoint: .top, endPoint: .bottom)
    static let pain = LinearGradient(colors: [Color(red: 1, green: 70/255, blue: 70/255), Color(red: 1, green: 150/255, blue: 70/255), Color(red: 1, green: 224/255, blue: 70/255), Color(red: 184/255, green: 234/255, blue: 95/255)], startPoint: .top, endPoint: .bottom)
    static let meals = [Color(red: 156/255, green: 228/255, blue: 46/255), AppColors.primary, Color(red: 229/255, green: 247/255, blue: 196/255)]
    static func label(_ date: Date, state: RecordDetailScreenState) -> String {
        if state.period == .day { return "\(state.calendar.component(.day, from: date))일" }
        if state.period == .week {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = state.calendar.timeZone; formatter.dateFormat = "EEEEE"
            return formatter.string(from: date)
        }
        let day = state.calendar.component(.day, from: date)
        return day == 1 || day.isMultiple(of: 5) ? String(day) : ""
    }
}

/// 좁은 월간 열 안에서도 10·15·20일이 줄바꿈되지 않도록 날짜 중심에 라벨을 놓습니다.
struct RecordDateAxis: View {
    let state: RecordDetailScreenState
    var leading: CGFloat = 20
    @ScaledMetric private var height: CGFloat = 18
    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(state.days.enumerated()), id: \.element) { index, date in
                Text(RecordChartStyle.label(date, state: state)).modifier(RecordTextStyle(size: 12))
                    .fixedSize().position(x: proxy.size.width * (CGFloat(index) + 0.5) / CGFloat(state.days.count), y: height/2)
            }
        }.frame(height: height).padding(.leading, leading).foregroundStyle(.secondary).accessibilityHidden(true)
    }
}
